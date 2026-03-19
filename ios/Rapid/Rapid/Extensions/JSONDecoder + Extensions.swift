//
//  JSONDecoder + Extensions.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/10/15.
//

import Foundation

extension JSONDecoder.DateDecodingStrategy {
    static var tolerantISO8601: JSONDecoder.DateDecodingStrategy {
        return .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            
            let withMs = ISO8601DateFormatter()
            withMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withMs.date(from: raw) {
                return date
            }
            
            let withoutMs = ISO8601DateFormatter()
            withoutMs.formatOptions = [.withInternetDateTime]
            if let date = withoutMs.date(from: raw) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Unexpected date format: \(raw)")
        }
    }
}
