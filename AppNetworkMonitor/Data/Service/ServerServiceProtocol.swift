//
//  ServerServiceProtocol.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 17/12/25.
//

import Foundation
import Network
import Combine

class ServerServiceProtocol: ObservableObject {
    let logReceived = PassthroughSubject<LogModel, Never>()
    @Published var isRunning = false
    @Published var hasConnectedClients = false
    @Published var connectedClientsCount = 0
    
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    
    // MARK: - Server Lifecycle
    
    func start() {
        if isRunning { return }
        
        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true

            let framerOptions = NWProtocolFramer.Options(definition: AppProtocol.definition)
            parameters.defaultProtocolStack.applicationProtocols.insert(framerOptions, at: 0)
            
            self.listener = try NWListener(using: parameters)
            self.listener?.service = NWListener.Service(name: "AppNetworkMonitor", type: "_appmonitor._tcp")
            
            self.listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        print("[AppNetworkMonitor] Listening...")
                        self?.isRunning = true
                    case .failed(let error):
                        print("[AppNetworkMonitor] Failure: \(error)")
                        self?.isRunning = false
                        self?.retryStart()
                    default: break
                    }
                }
            }
            
            self.listener?.newConnectionHandler = { [weak self] connection in
                print("[AppNetworkMonitor] Client connected!")
                self?.setupConnection(connection)
            }
            
            self.listener?.start(queue: .main)
            
        } catch {
            print("[AppNetworkMonitor] Start error: \(error)")
            isRunning = false
        }
    }
    
    private func retryStart() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.start()
        }
    }
    
    func stop() {
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        isRunning = false
        hasConnectedClients = false
        connectedClientsCount = 0
    }
    
    private func setupConnection(_ connection: NWConnection) {
        connections.append(connection)
        DispatchQueue.main.async {
            self.hasConnectedClients = true
            self.connectedClientsCount = self.connections.count
        }
        
        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state { self?.cleanup(connection) }
            if case .failed(_) = state { self?.cleanup(connection) }
        }
        
        connection.start(queue: .main)
        receiveMessage(on: connection)
    }
    
    private func cleanup(_ connection: NWConnection) {
        connections.removeAll(where: { $0 === connection })
        DispatchQueue.main.async {
            self.hasConnectedClients = !self.connections.isEmpty
            self.connectedClientsCount = self.connections.count
        }
    }
    
    private func receiveMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] (data, context, isComplete, error) in
            if let error = error {
                print("[AppNetworkMonitor] Receive message error: \(error)")
                connection.cancel()
                return
            }
            
            if let data = data, !data.isEmpty {
                self?.decode(data)
            }
            
            if error == nil {
                self?.receiveMessage(on: connection)
            }
        }
    }
    
    private func decode(_ data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let message = try? decoder.decode(SocketMessage.self, from: data) {
            handleSocketMessage(message, decoder: decoder)
            return
        }
        
        do {
            let log = try decoder.decode(LogModel.self, from: data)
            DispatchQueue.main.async {
                self.logReceived.send(log)
            }
        } catch {
            print("[AppNetworkMonitor] JSON decode error: \(error)")
            if let str = String(data: data, encoding: .utf8) {
                print("[AppNetworkMonitor] Received data: \(str)")
            }
        }
    }
    
    private func handleSocketMessage(_ message: SocketMessage, decoder: JSONDecoder) {
        switch message.type {
        case .log:
            if let log = try? decoder.decode(LogModel.self, from: message.payload) {
                DispatchQueue.main.async {
                    self.logReceived.send(log)
                }
            }
        default:
            break
        }
    }
    
    // MARK: - Mock Rule Methods
    
    func sendMockRule(_ rule: MockRule) {
        let encoder = JSONEncoder()
        
        guard let payload = try? encoder.encode(rule) else { return }
        
        let message = SocketMessage(type: .addMockRule, payload: payload)
        guard let data = try? encoder.encode(message) else { return }
        
        sendToAllConnections(data)
    }
    
    func removeMockRule(id: UUID) {
        let encoder = JSONEncoder()
        
        guard let payload = try? encoder.encode(id) else { return }
        
        let message = SocketMessage(type: .removeMockRule, payload: payload)
        guard let data = try? encoder.encode(message) else { return }
        
        sendToAllConnections(data)
    }
    
    func clearAllMockRules() {
        let message = SocketMessage(type: .clearMockRules, payload: Data())
        guard let data = try? JSONEncoder().encode(message) else { return }
        
        sendToAllConnections(data)
    }
    
    func syncMockRules(_ rules: [MockRule]) {
        let encoder = JSONEncoder()
        
        guard let payload = try? encoder.encode(rules) else { return }
        
        let message = SocketMessage(type: .syncMockRules, payload: payload)
        guard let data = try? encoder.encode(message) else { return }
        
        sendToAllConnections(data)
    }
    
    private func sendToAllConnections(_ data: Data) {
        for connection in connections {
            let framerMessage = NWProtocolFramer.Message(definition: AppProtocol.definition)
            let context = NWConnection.ContentContext(identifier: "SocketMessage", metadata: [framerMessage])
            
            connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { error in
                if let error = error {
                    print("[AppNetworkMonitor] Send error: \(error)")
                }
            })
        }
    }
}
