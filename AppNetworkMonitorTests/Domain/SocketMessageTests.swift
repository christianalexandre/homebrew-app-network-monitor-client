import Foundation
import Testing
@testable import AppNetworkMonitor

struct SocketMessageTests {

    @Test func socketMessageCodableRoundtrip() throws {
        let payload = Data("hello".utf8)
        let message = SocketMessage(type: .log, payload: payload)
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(SocketMessage.self, from: data)
        #expect(decoded.type == .log)
        #expect(decoded.payload == payload)
    }

    @Test func socketMessageTypeRawValues() {
        #expect(SocketMessageType.log.rawValue == "LOG")
        #expect(SocketMessageType.addMockRule.rawValue == "ADD_MOCK_RULE")
        #expect(SocketMessageType.removeMockRule.rawValue == "REMOVE_MOCK_RULE")
        #expect(SocketMessageType.clearMockRules.rawValue == "CLEAR_MOCK_RULES")
        #expect(SocketMessageType.syncMockRules.rawValue == "SYNC_MOCK_RULES")
    }

    @Test func socketMessageTypeDecodesFromKnownString() throws {
        let data = Data("\"ADD_MOCK_RULE\"".utf8)
        let decoded = try JSONDecoder().decode(SocketMessageType.self, from: data)
        #expect(decoded == .addMockRule)
    }

    @Test func nestedMockRulePayloadRoundtrip() throws {
        let rule = MockRule(path: "/api/x", statusCode: 201)
        let inner = try JSONEncoder().encode(rule)
        let envelope = SocketMessage(type: .addMockRule, payload: inner)
        let outer = try JSONEncoder().encode(envelope)

        let decodedEnvelope = try JSONDecoder().decode(SocketMessage.self, from: outer)
        #expect(decodedEnvelope.type == .addMockRule)
        let decodedRule = try JSONDecoder().decode(MockRule.self, from: decodedEnvelope.payload)
        #expect(decodedRule == rule)
    }
}
