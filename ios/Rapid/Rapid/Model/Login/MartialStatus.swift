//
//  MartialStatus.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/13.
//

import Foundation
import SwiftUI

struct MartialStatus: Identifiable, Codable, Equatable {
    var id: UUID = .init()
    var status: MartialStatusType
}

enum MartialStatusType: String, Codable, Equatable {
    case single = "未婚"
    case married = "既婚"
    case divorced = "離婚"
    case widowed = "死別"
}