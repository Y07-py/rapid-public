//
//  DeviceToken.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/19.
//

import Foundation
import SwiftUI

public struct VoIPDeviceToken: Codable {
    public let userId: UUID
    public let deviceToken: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceToken = "device_token"
    }
}
