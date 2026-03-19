//
//  MeetingPlan.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/09/02.
//

import Foundation
import SwiftUI

struct MeetingPlan: Codable, Identifiable, Equatable {
    var id: UUID = .init()
    var category: String
    var code: Int
}

struct MeetingPlanCategory: Codable, Identifiable, Equatable {
    var id: UUID = .init()
    var categoryId1: Int
    var categoryId2: Int
    var category: String
    var thumbnail: URL? = nil
    
    enum CodingKeys: String, CodingKey {
        case categoryId1 = "category_id1"
        case categoryId2 = "category_id2"
        case category
    }
}
