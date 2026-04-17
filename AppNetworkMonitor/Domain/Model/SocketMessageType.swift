import Foundation

public enum SocketMessageType: String, Codable {
    case log = "LOG"
    case addMockRule = "ADD_MOCK_RULE"
    case removeMockRule = "REMOVE_MOCK_RULE"
    case clearMockRules = "CLEAR_MOCK_RULES"
    case syncMockRules = "SYNC_MOCK_RULES"
}
