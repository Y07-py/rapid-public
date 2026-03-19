//
//  Sex.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/08.
//

import Foundation
import SwiftUI

struct Sex: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = .init()
    var type: Gender
}

enum Gender: String, Codable, Equatable {
    case man = "男性"
    case woman = "女性"
    
    var dbValue: String {
        switch self {
        case .man: return "man"
        case .woman: return "woman"
        }
    }
}
