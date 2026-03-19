//
//  BloodType.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/13.
//

import Foundation
import SwiftUI

struct BloodType: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = .init()
    var type: Blood
}

enum Blood: String, Codable, Equatable {
    case A = "A型"
    case B = "B型"
    case AB = "AB型"
    case O = "O型"
}
