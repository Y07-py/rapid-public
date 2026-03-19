//
//  Profile.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/03/08.
//

import Foundation
import SwiftUI

public struct UploadProfileMetaData: Codable {
    public var user: RapidUser
    public var keywords: [KeyWordTag]
    
    enum CodingKeys: String, CodingKey {
        case user
        case keywords
    }
}
