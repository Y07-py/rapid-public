//
//  DeviceToken.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/10/28.
//

import Foundation
import SwiftUI

public struct DeviceToken: Codable {
    public var uid: String
    public var token: String
    public var createdAt: Date
    
    public init(uid: String, token: String, createdAt: Date) {
        self.uid = uid
        self.token = token
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case uid
        case token
        case createdAt = "created_at"
    }
}




