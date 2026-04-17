import Foundation
import Testing
@testable import AppNetworkMonitor

struct MockRuleTests {

    @Test func defaultsAreApplied() {
        let rule = MockRule(path: "/api/users")
        #expect(rule.path == "/api/users")
        #expect(rule.method == nil)
        #expect(rule.statusCode == 200)
        #expect(rule.responseHeaders == nil)
        #expect(rule.responseBody == nil)
        #expect(rule.delayMs == 0)
        #expect(rule.isEnabled == true)
    }

    @Test func customValuesArePreserved() {
        let id = UUID()
        let rule = MockRule(
            id: id,
            path: "/api/x",
            method: "POST",
            statusCode: 418,
            responseHeaders: ["X": "Y"],
            responseBody: "{}",
            delayMs: 250,
            isEnabled: false
        )
        #expect(rule.id == id)
        #expect(rule.method == "POST")
        #expect(rule.statusCode == 418)
        #expect(rule.responseHeaders == ["X": "Y"])
        #expect(rule.responseBody == "{}")
        #expect(rule.delayMs == 250)
        #expect(rule.isEnabled == false)
    }

    @Test func codableRoundtrip() throws {
        let rule = MockRule(
            path: "/api/x",
            method: "PUT",
            statusCode: 201,
            responseHeaders: ["A": "B"],
            responseBody: "{\"ok\":true}",
            delayMs: 100,
            isEnabled: true
        )
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(MockRule.self, from: data)
        #expect(decoded == rule)
    }

    @Test func equalRulesHaveSameHash() {
        let id = UUID()
        let a = MockRule(id: id, path: "/x")
        let b = MockRule(id: id, path: "/x")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}
