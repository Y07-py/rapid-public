//
//  UIColor+Extention.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/09.
//

import Foundation
import UIKit

extension UIColor {
    convenience init?(hex: String) {
        var hexSentized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
        hexSentized = hexSentized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = .zero
        guard Scanner(string: hexSentized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSentized.count
        switch length {
        case 6:
            let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            let blue = CGFloat((rgb & 0x0000FF)) / 255.0
            self.init(red: red, green: green, blue: blue, alpha: 1.0)
        case 8:
            let red = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            let green = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            let blue = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            let alpha = CGFloat((rgb & 0x000000FF)) / 255.0
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        default:
            return nil
        }
    }
    
    convenience init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1.0) {
        self.init(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
    }
    
    static var offWhiteOrBlack: UIColor {
        return UIColor { (traitCollection: UITraitCollection) -> UIColor in
            let rgbValue: CGFloat = traitCollection.userInterfaceStyle == .dark ? 0 : 247
            return UIColor(r: rgbValue, g: rgbValue, b: rgbValue)
        }
    }
}
