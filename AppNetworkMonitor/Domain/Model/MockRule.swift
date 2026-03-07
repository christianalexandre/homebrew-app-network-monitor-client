//
//  MockRule.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 06/03/26.
//

import Foundation

public struct MockRule: Codable, Hashable, Identifiable {
    public let id: UUID
    public let path: String
    public let method: String?
    public let statusCode: Int
    public let responseHeaders: [String: String]?
    public let responseBody: String?
    public let delayMs: Int
    public let isEnabled: Bool
    
    public init(
        id: UUID = UUID(),
        path: String,
        method: String? = nil,
        statusCode: Int = 200,
        responseHeaders: [String: String]? = nil,
        responseBody: String? = nil,
        delayMs: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.path = path
        self.method = method
        self.statusCode = statusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.delayMs = delayMs
        self.isEnabled = isEnabled
    }
}
