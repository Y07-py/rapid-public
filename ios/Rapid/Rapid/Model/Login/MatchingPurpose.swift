//
//  MatchingPurpose.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/13.
//

import Foundation
import SwiftUI

struct MatchingPurpose: Identifiable, Codable, Equatable {
    var id: UUID = .init()
    var purpose: MatchingPurposeType
}

enum MatchingPurposeType: String, Codable, Equatable {
    case seriousRelationship = "真剣な交際"
    case dating = "恋人探し"
    case friendship = "友達作り"
    case hobbyFriend = "趣味仲間探し"
    case penFriend = "メル友探し"
    case other = "その他"
}
