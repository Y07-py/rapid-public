//
//  Prefetcure.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/13.
//

import Foundation
import SwiftUI

struct Prefecture: Identifiable, Codable, Equatable {
    var id: UUID = .init()
    var code: Int
    var name: String
    
    enum CodingKeys: String, CodingKey {
        case code = "都道府県コード"
        case name = "都道府県"
    }
}

public struct City: Identifiable, Hashable {
    public var id: UUID = .init()
    public let cityName: String
    public let prefName: String
    public let latitude: Double
    public let longitude: Double
    
    public var name: String {
        "\(prefName) \(cityName)"
    }
}


