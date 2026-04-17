import Testing
@testable import AppNetworkMonitor

struct ServerStatusTests {

    @Test func stoppedLabel() {
        #expect(ServerStatus.stopped.label == "Stopped")
    }

    @Test func startingLabel() {
        #expect(ServerStatus.starting.label == "Starting...")
    }

    @Test func listeningLabelIncludesPort() {
        #expect(ServerStatus.listening(port: 8080).label == "Listening on :8080")
    }

    @Test func failedLabelIncludesError() {
        #expect(ServerStatus.failed(error: "boom").label == "Error: boom")
    }

    @Test func equality() {
        #expect(ServerStatus.stopped == ServerStatus.stopped)
        #expect(ServerStatus.listening(port: 80) == ServerStatus.listening(port: 80))
        #expect(ServerStatus.listening(port: 80) != ServerStatus.listening(port: 81))
    }
}
