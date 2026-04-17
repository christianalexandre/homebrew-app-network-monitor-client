import Foundation
import Network
import Combine
import OSLog

@MainActor
protocol ServerServicing: AnyObject {
    var logReceived: PassthroughSubject<LogModel, Never> { get }
    var isRunning: Bool { get }
    var connectedClientsCount: Int { get }
    var isRunningPublisher: AnyPublisher<Bool, Never> { get }
    var connectedClientsCountPublisher: AnyPublisher<Int, Never> { get }

    func start()
    func stop()
    func sendMockRule(_ rule: MockRule)
    func removeMockRule(id: UUID)
    func clearAllMockRules()
    func syncMockRules(_ rules: [MockRule])
}

@MainActor
final class ServerService: ObservableObject, ServerServicing {
    let logReceived = PassthroughSubject<LogModel, Never>()
    @Published var isRunning = false
    @Published var connectedClientsCount = 0

    var isRunningPublisher: AnyPublisher<Bool, Never> { $isRunning.eraseToAnyPublisher() }
    var connectedClientsCountPublisher: AnyPublisher<Int, Never> { $connectedClientsCount.eraseToAnyPublisher() }

    nonisolated private static let logger = Logger(subsystem: "AppNetworkMonitor", category: "ServerService")
    private static let retryBaseDelay: TimeInterval = 2
    private static let retryMaxDelay: TimeInterval = 30

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var retryAttempt = 0
    private var stopRequested = false

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private lazy var encoder = JSONEncoder()

    // MARK: - Server Lifecycle

    func start() {
        if isRunning { return }
        stopRequested = false

        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true

            let framerOptions = NWProtocolFramer.Options(definition: AppProtocol.definition)
            parameters.defaultProtocolStack.applicationProtocols.insert(framerOptions, at: 0)

            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(name: "AppNetworkMonitor", type: "_appmonitor._tcp")

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleListenerState(state)
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.setupConnection(connection)
                }
            }

            self.listener = listener
            listener.start(queue: .main)

        } catch {
            Self.logger.error("Start error: \(error.localizedDescription, privacy: .public)")
            isRunning = false
            scheduleRetry()
        }
    }

    func stop() {
        stopRequested = true
        retryAttempt = 0

        listener?.cancel()
        listener = nil

        let toCancel = connections
        connections.removeAll()
        toCancel.forEach { $0.cancel() }

        isRunning = false
        connectedClientsCount = 0
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            Self.logger.info("Listening")
            retryAttempt = 0
            isRunning = true
        case .failed(let error):
            Self.logger.error("Listener failure: \(error.localizedDescription, privacy: .public)")
            isRunning = false
            scheduleRetry()
        default:
            break
        }
    }

    private func scheduleRetry() {
        guard !stopRequested else { return }
        let delay = min(Self.retryBaseDelay * pow(2, Double(retryAttempt)), Self.retryMaxDelay)
        retryAttempt += 1
        Self.logger.info("Retrying server start in \(delay, privacy: .public)s (attempt \(self.retryAttempt, privacy: .public))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard !self.stopRequested else { return }
            self.start()
        }
    }

    private func setupConnection(_ connection: NWConnection) {
        connections.append(connection)
        connectedClientsCount = connections.count

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .cancelled, .failed:
                    self.cleanup(connection)
                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
        receiveMessage(on: connection)
    }

    private func cleanup(_ connection: NWConnection) {
        guard connections.contains(where: { $0 === connection }) else { return }
        connections.removeAll(where: { $0 === connection })
        connectedClientsCount = connections.count
    }

    private func receiveMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    Self.logger.error("Receive error: \(error.localizedDescription, privacy: .public)")
                    connection.cancel()
                    return
                }

                if let data, !data.isEmpty {
                    self.decode(data)
                }

                self.receiveMessage(on: connection)
            }
        }
    }

    private func decode(_ data: Data) {
        do {
            let message = try decoder.decode(SocketMessage.self, from: data)
            handleSocketMessage(message)
        } catch {
            Self.logger.error("Decode error: \(error.localizedDescription, privacy: .public)")
            if let str = String(data: data, encoding: .utf8) {
                Self.logger.debug("Received payload: \(str, privacy: .public)")
            }
        }
    }

    private func handleSocketMessage(_ message: SocketMessage) {
        switch message.type {
        case .log:
            do {
                let log = try decoder.decode(LogModel.self, from: message.payload)
                logReceived.send(log)
            } catch {
                Self.logger.error("Log payload decode error: \(error.localizedDescription, privacy: .public)")
            }
        default:
            break
        }
    }

    // MARK: - Mock Rule Methods

    func sendMockRule(_ rule: MockRule) {
        guard let payload = try? encoder.encode(rule) else { return }
        send(.init(type: .addMockRule, payload: payload))
    }

    func removeMockRule(id: UUID) {
        guard let payload = try? encoder.encode(id) else { return }
        send(.init(type: .removeMockRule, payload: payload))
    }

    func clearAllMockRules() {
        send(.init(type: .clearMockRules, payload: Data()))
    }

    func syncMockRules(_ rules: [MockRule]) {
        guard let payload = try? encoder.encode(rules) else { return }
        send(.init(type: .syncMockRules, payload: payload))
    }

    private func send(_ message: SocketMessage) {
        guard let data = try? encoder.encode(message) else { return }
        sendToAllConnections(data)
    }

    private func sendToAllConnections(_ data: Data) {
        for connection in connections {
            let framerMessage = NWProtocolFramer.Message(definition: AppProtocol.definition)
            let context = NWConnection.ContentContext(identifier: "SocketMessage", metadata: [framerMessage])

            connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { error in
                if let error {
                    Self.logger.error("Send error: \(error.localizedDescription, privacy: .public)")
                }
            })
        }
    }
}
