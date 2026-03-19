//
//  KeywordTag.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/19.
//

import Foundation
import SwiftUI

public struct KeyWordTag: Codable, Identifiable {
    public let id: UUID
    var userId: UUID? = nil
    let keyword: String
    let category: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case keyword
        case category
    }
}
