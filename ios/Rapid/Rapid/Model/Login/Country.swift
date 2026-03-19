//
//  Country.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/09.
//

import Foundation
import SwiftUI

struct Country: Identifiable, Hashable, Equatable {
    var id: String { region }
    var flag: String
    var region: String
    var code: UInt64
    
    init(flag: String, region: String, code: UInt64) {
        self.flag = flag
        self.region = region
        self.code = code
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(region)
        hasher.combine(code)
    }
    
    static func == (lhs: Country, rhs: Country) -> Bool {
        return lhs.region == rhs.region && lhs.code == rhs.code
    }
}
