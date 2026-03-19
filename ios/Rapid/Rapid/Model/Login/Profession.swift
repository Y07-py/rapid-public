//
//  Profession.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/13.
//

import Foundation
import SwiftUI

public struct Profession: Identifiable, Hashable {
    public var id: UUID = .init()
    public let category: String
    public let name: String
}
