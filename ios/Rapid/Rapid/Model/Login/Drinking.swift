//
//  Drinking.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/14.
//

import Foundation
import SwiftUI

struct Drinking: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = .init()
    var style: DrinkStyle
}

enum DrinkStyle: String, Codable {
    case none = "全く飲まない"
    case sometime = "たまに飲む"
    case often = "よく飲む"
}


