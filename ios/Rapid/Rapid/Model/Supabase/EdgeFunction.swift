//
//  EdgeFunction.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/10/28.
//

import Foundation
import SwiftUI

public struct LikePairNotificationPayLoad: Codable {
    public var userId: String
    public var title: String? = nil
    public var body: String? = nil
    public var custom: [String: String]? = nil
    public var pushType: String? = nil
    public var badge: Int? = nil
    
    public init(
        userId: String,
        title: String? = nil,
        body: String? = nil,
        custom: [String: String]? = nil,
        pushType: String? = nil,
        badge: Int? = nil
    ) {
        self.userId = userId
        self.title = title
        self.body = body
        self.custom = custom
        self.pushType = pushType
        self.badge = badge
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case title
        case body
        case custom
        case pushType = "push_type"
        case badge
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        custom = try container.decodeIfPresent([String: String].self, forKey: .custom)
        pushType = try container.decodeIfPresent(String.self, forKey: .pushType)
        badge = try container.decodeIfPresent(Int.self, forKey: .badge)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(custom, forKey: .custom)
        try container.encodeIfPresent(pushType, forKey: .pushType)
        try container.encodeIfPresent(badge, forKey: .badge)
    }
}

public struct MatchPairNotificationPayload: Codable {
    public var userAId: String
    public var userBId: String
    public var title: String
    public var body: String
    public var pushType: String
    public var badge: Int
    
    init(userAId: String, userBId: String, title: String, body: String, pushType: String, badge: Int = 1) {
        self.userAId = userAId
        self.userBId = userBId
        self.title = title
        self.body = body
        self.pushType = pushType
        self.badge = badge
    }
    
    enum CodingKeys: String, CodingKey {
        case userAId = "user_a_id"
        case userBId = "user_b_id"
        case title
        case body
        case pushType = "push_type"
        case badge
    }
}
