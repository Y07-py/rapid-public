//
//  FCMPayload.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/31.
//

import Foundation
import SwiftUI

public struct FCMPayload: Codable {
    public var fcmToken: String
    public var deviceType: String
    public var appVersion: String
    public var deviceModel: String
    
    enum CodingKeys: String, CodingKey {
        case fcmToken = "fcm_token"
        case deviceType = "device_type"
        case appVersion = "app_version"
        case deviceModel = "device_model"
    }
}
