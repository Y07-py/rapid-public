//
//  SessionDescription.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/14.
//

import Foundation
import WebRTC

enum SDPType: String, Codable {
    case offer
    case prAnswer
    case answer
    
    var rtcSDPType: RTCSdpType {
        switch self {
        case .offer: return .offer
        case .prAnswer: return .prAnswer
        case .answer: return .answer
        }
    }
}

public struct SessionDescription: Codable {
    var sdp: String
    var type: SDPType
    
    init(from rtcSessionDescription: RTCSessionDescription) {
        self.sdp = rtcSessionDescription.sdp
        
        switch rtcSessionDescription.type {
        case .offer: self.type = .offer
        case .prAnswer: self.type = .prAnswer
        case .answer: self.type = .answer
        @unknown default:
            fatalError("Unknown RTCSessiionDescription type: \(rtcSessionDescription.type.rawValue)")
        }
    }
    
    var rtcSessionDescription: RTCSessionDescription {
        return RTCSessionDescription(type: self.type.rtcSDPType, sdp: self.sdp)
    }
}
