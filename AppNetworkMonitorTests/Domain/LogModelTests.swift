import Foundation
import Testing
@testable import AppNetworkMonitor

struct LogModelTests {

    private func makeLog(
        url: String = "https://api.example.com/v1/users?page=2",
        statusCode: Int = 200,
        timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> LogModel {
        LogModel(
            id: UUID(),
            timestamp: timestamp,
            method: "GET",
            url: url,
            statusCode: statusCode,
            duration: 0.123,
            requestHeaders: ["Content-Type": "application/json"],
            responseHeaders: nil,
            requestBody: nil,
            responseBody: nil
        )
    }

    @Test func hostExtractsFromUrl() {
        #expect(makeLog(url: "https://api.example.com/x").host == "api.example.com")
    }

    @Test func hostFallsBackToUnknownForInvalidUrl() {
        #expect(makeLog(url: "not a url at all").host == "Unknown")
    }

    @Test func pathExtractsFromUrl() {
        #expect(makeLog(url: "https://x.com/v1/users").path == "/v1/users")
    }

    @Test func pathFallsBackToSlashForInvalidUrl() {
        #expect(makeLog(url: "").path == "/")
    }

    @Test func queryReturnsValueWhenPresent() {
        #expect(makeLog(url: "https://x.com/a?b=1&c=2").query == "b=1&c=2")
    }

    @Test func queryReturnsNilWhenAbsent() {
        #expect(makeLog(url: "https://x.com/a").query == nil)
    }

    @Test func isErrorTrueFor4xx() {
        #expect(makeLog(statusCode: 404).isError)
    }

    @Test func isErrorTrueFor5xx() {
        #expect(makeLog(statusCode: 500).isError)
    }

    @Test func isErrorFalseFor2xx() {
        #expect(!makeLog(statusCode: 200).isError)
    }

    @Test func isErrorFalseFor3xx() {
        #expect(!makeLog(statusCode: 301).isError)
    }

    @Test func formattedTimeUsesHmsMillis() {
        let log = makeLog(timestamp: Date(timeIntervalSince1970: 0))
        // 1970-01-01 00:00:00.000 in local TZ; we just check structure HH:mm:ss.SSS
        let parts = log.formattedTime.split(separator: ".")
        #expect(parts.count == 2)
        #expect(parts[1].count == 3)
        #expect(parts[0].split(separator: ":").count == 3)
    }

    @Test func codableRoundtrip() throws {
        let log = makeLog()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(log)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LogModel.self, from: data)

        #expect(decoded == log)
    }
}
