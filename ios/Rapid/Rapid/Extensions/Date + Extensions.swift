//
//  Date + Extensions.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/30.
//

import Foundation

extension Date {
    func computeAge() -> Int {
        let calendar = Calendar.current
        let now = Date.now
        let age = calendar.dateComponents([.year], from: self, to: now)
        
        return age.year ?? 0
    }
}
