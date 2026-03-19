//
//  MBTI.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/24.
//

import Foundation

public struct MBTI: Identifiable, Codable, Hashable {
    public var id: UUID = .init()
    public let name: String
    public let thumbnailURL: URL
}
