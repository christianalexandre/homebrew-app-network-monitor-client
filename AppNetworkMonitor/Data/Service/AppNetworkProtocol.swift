import Network
import Foundation
import OSLog

class AppProtocol: NWProtocolFramerImplementation {
    static let label = "AppMonitorProtocol"
    static let definition = NWProtocolFramer.Definition(implementation: AppProtocol.self)

    static let maxMessageSize = 30 * 1024 * 1024 // 30 MB

    private static let headerSize = 4
    private static let logger = Logger(subsystem: "AppNetworkMonitor", category: "AppProtocol")

    required init(framer: NWProtocolFramer.Instance) {}
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { .ready }
    func wakeup(framer: NWProtocolFramer.Instance) {}
    func stop(framer: NWProtocolFramer.Instance) -> Bool { true }
    func cleanup(framer: NWProtocolFramer.Instance) {}

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var parsedLength: UInt32 = 0

            let parsed = framer.parseInput(minimumIncompleteLength: Self.headerSize,
                                           maximumLength: Self.headerSize) { buffer, _ -> Int in
                guard let buffer, buffer.count >= Self.headerSize else { return 0 }
                parsedLength = UInt32(bigEndian: buffer.loadUnaligned(fromByteOffset: 0, as: UInt32.self))
                return Self.headerSize
            }

            guard parsed else { return Self.headerSize }

            let messageSize = Int(parsedLength)
            if messageSize <= 0 || messageSize > Self.maxMessageSize {
                Self.logger.error("Rejecting oversized message: \(messageSize, privacy: .public) bytes (max \(Self.maxMessageSize, privacy: .public))")
                framer.markFailed(error: NWError.posix(.EMSGSIZE))
                return 0
            }

            let header = NWProtocolFramer.Message(definition: AppProtocol.definition)
            header["length"] = parsedLength

            if !framer.deliverInputNoCopy(length: messageSize, message: header, isComplete: true) {
                return 0
            }
        }
    }

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        var length = UInt32(messageLength).bigEndian
        framer.writeOutput(data: Data(bytes: &length, count: Self.headerSize))

        try? framer.writeOutputNoCopy(length: messageLength)
    }
}
