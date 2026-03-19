//
//  SignalMessage.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/14.
//

import Foundation
import WebRTC


enum SignalType: Codable {
    case sdp(SessionDescription)
    case candidate(IceCandidate)
    case bye
}

public struct SignalMessage: Codable {
    // Message structure for signaling via Supabase Realtime.
    var type: SignalType
    var senderId: String
    var callId: String
    
    init(type: SignalType, senderId: String, callId: String) {
        self.type = type
        self.senderId = senderId
        self.callId = callId
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case senderId = "sender_id"
        case callId = "call_id"
        case payload
    }
    
    enum DecodingError: Error {
        case unknownType
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case String(describing: SessionDescription.self):
            self.type = .sdp(try container.decode(SessionDescription.self, forKey: .payload))
        case String(describing: IceCandidate.self):
            self.type = .candidate(try container.decode(IceCandidate.self, forKey: .payload))
        case "bye":
            self.type = .bye
        default:
            throw DecodingError.unknownType
        }
        self.callId = try container.decode(String.self, forKey: .callId)
        self.senderId = try container.decode(String.self, forKey: .senderId)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self.type {
        case .sdp(let sessionDescription):
            try container.encode(sessionDescription, forKey: .payload)
            try container.encode(String(describing: SessionDescription.self), forKey: .type)
        case .candidate(let iceCandidate):
            try container.encode(iceCandidate, forKey: .payload)
            try container.encode(String(describing: IceCandidate.self), forKey: .type)
        case .bye:
            try container.encode("bye", forKey: .type)
        }
        
        try container.encode(senderId, forKey: .senderId)
        try container.encode(callId, forKey: .callId)
    }
}
