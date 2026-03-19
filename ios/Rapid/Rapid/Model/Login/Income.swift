//
//  Untitled.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/14.
//

import Foundation
import SwiftUI

struct Income: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = .init()
    var income: IncomRange
}

enum IncomRange: String, Codable {
    case under200 = "200万円未満"
    case range200to400 = "200万円〜400万円"
    case range400to600 = "400万円〜600万円"
    case range600to800 = "600万円〜800万円"
    case range800to1000 = "800万円〜1000万円"
    case over1000 = "1000万円以上"
}
