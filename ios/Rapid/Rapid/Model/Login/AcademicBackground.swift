//
//  Academic.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/14.
//

import Foundation
import SwiftUI

struct AcademicBackground: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = .init()
    var academic: Academic
}

enum Academic: String, Codable, Hashable {
    case highSchoolGraduate = "高卒"
    case universityGraduate = "大卒"
    case gradSchoolGraduate = "大学院卒"
    case other = "その他"
}
