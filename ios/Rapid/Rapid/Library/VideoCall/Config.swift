//
//  Config.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/17.
//

import Foundation

fileprivate let defaultIceServers = ["stun:stun.l.google.com:19302",
                                     "stun:stun1.l.google.com:19302",
                                     "stun:stun2.l.google.com:19302",
                                     "stun:stun3.l.google.com:19302",
                                     "stun:stun4.l.google.com:19302"]

public struct Config {
    let webRTCIceServers: [String]
    
    static let `default` = Config(webRTCIceServers: defaultIceServers)
}
