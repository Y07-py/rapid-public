//
//  Smoking.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/13.
//

import Foundation
import SwiftUI

struct Smoking: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = .init()
    var style: SmokingStyle
}

enum SmokingStyle: String, Codable, Equatable {
    case none = "吸わない"
    case sometimes = "たまに吸う"
    case oftentimes = "よく吸う"
}
