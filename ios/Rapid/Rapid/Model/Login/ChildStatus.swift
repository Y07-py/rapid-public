//
//  ChildStatus.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/13.
//

import Foundation
import SwiftUI

struct ChildStatus: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = .init()
    var status: ChildStatusType
}

enum ChildStatusType: String, Codable, Equatable {
    case none = "子どもなし"
    case living = "子どもあり"
}
