//
//  JSONEncoder + Extensions.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/01.
//

import Foundation

extension JSONEncoder.DateEncodingStrategy {
    static var tolerantISO8601: JSONEncoder.DateEncodingStrategy {
        return .custom { date, encoder in
            var container = encoder.singleValueContainer()
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds   
            ]
            
            let dateString = formatter.string(from: date)
            try container.encode(dateString)
        }
    }
}
