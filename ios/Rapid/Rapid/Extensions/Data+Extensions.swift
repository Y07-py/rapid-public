//
//  Data+Extensions.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/25.
//

import Foundation

extension Data {
    mutating func append(_ s: String) {
        append(s.data(using: .utf8)!)
    }
    
    static func utf8(_ s: String) -> Data {
        Data(s.utf8)
    }
}
