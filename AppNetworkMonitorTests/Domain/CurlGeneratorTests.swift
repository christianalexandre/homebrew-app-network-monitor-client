import Foundation
import Testing
@testable import AppNetworkMonitor

struct CurlGeneratorTests {

    private func makeLog(
        method: String = "GET",
        url: String = "https://api.example.com/x",
        requestHeaders: [String: String]? = nil,
        requestBody: String? = nil
    ) -> LogModel {
        LogModel(
            id: UUID(),
            timestamp: Date(),
            method: method,
            url: url,
            statusCode: 200,
            duration: 0,
            requestHeaders: requestHeaders,
            responseHeaders: nil,
            requestBody: requestBody,
            responseBody: nil
        )
    }

    @Test func minimalCurlContainsMethodAndUrl() {
        let curl = CurlGenerator.generate(from: makeLog(method: "POST", url: "https://x.com/y"))
        #expect(curl.contains("curl -v"))
        #expect(curl.contains("-X POST"))
        #expect(curl.contains("\"https://x.com/y\""))
    }

    @Test func headersAreEmittedAsDashH() {
        let curl = CurlGenerator.generate(from: makeLog(requestHeaders: ["Authorization": "Bearer token"]))
        #expect(curl.contains("-H \"Authorization: Bearer token\""))
    }

    @Test func contentLengthHeaderIsSkipped() {
        let curl = CurlGenerator.generate(from: makeLog(requestHeaders: ["Content-Length": "42", "X-Other": "v"]))
        #expect(!curl.contains("Content-Length"))
        #expect(curl.contains("X-Other"))
    }

    @Test func contentLengthHeaderSkippedCaseInsensitive() {
        let curl = CurlGenerator.generate(from: makeLog(requestHeaders: ["content-length": "42"]))
        #expect(!curl.lowercased().contains("content-length"))
    }

    @Test func bodyIsEmittedAndQuotesAreEscaped() {
        let curl = CurlGenerator.generate(from: makeLog(requestBody: "{\"a\":\"b\"}"))
        #expect(curl.contains("-d \"{\\\"a\\\":\\\"b\\\"}\""))
    }

    @Test func emptyBodyIsNotEmitted() {
        let curl = CurlGenerator.generate(from: makeLog(requestBody: ""))
        #expect(!curl.contains("-d "))
    }

    @Test func nilBodyIsNotEmitted() {
        let curl = CurlGenerator.generate(from: makeLog(requestBody: nil))
        #expect(!curl.contains("-d "))
    }
}
