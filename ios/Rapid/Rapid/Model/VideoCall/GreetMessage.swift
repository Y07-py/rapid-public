//
//  ReadyMessage.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/18.
//

import Foundation

public enum GreetType: String, Codable {
    case hi = "hi"
    case bye = "bye"
}

public struct GreetMessage: Codable {
    public var callId: String
    public var senderId: String
    public var type: GreetType
    
    enum CodingKeys: String, CodingKey {
        case callId = "call_id"
        case senderId = "sender_id"
        case type
    }
}
