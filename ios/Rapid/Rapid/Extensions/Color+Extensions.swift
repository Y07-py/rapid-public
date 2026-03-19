//
//  Color+Extension.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/09.
//

import Foundation
import SwiftUI

extension Color {
    init?(hex: String) {
        guard let uiColor = UIColor(hex: hex) else { return nil }
        self.init(uiColor: uiColor)
    }
    
    static var buttonColor: Self? {
        guard let color = self.init(hex: "000000") else { return nil }
        return color
    }
    
    static var mainColor: Self {
        return self.init(hex: "F73F52") ?? .clear
    }
    
    static var backgroundColor: Self {
        return self.init(hex: "F3F2EC") ?? .clear
    }
    
    static var subFontColor: Self {
        return self.init(hex: "3D0301") ?? .clear
    }
    
    static var thirdColor: Self {
        return self.init(hex: "6367FF") ?? .clear
    }
    
    static var selectedColor: Self {
        return self.init(hex: "093FB4") ?? .clear
    }
    
    static var lightGreen: Self? {
        guard let color = self.init(hex: "08CB00") else { return nil }
        return color
    }
    
    static var lightRed: Self? {
        guard let color = self.init(hex: "FF5A5F") else { return nil }
        return color
    }
    
    static var pointBarColor: Self {
        return self.init(hex: "ED775A") ?? .clear
    }
    
    static var subscriptionColor: Self {
        return self.init(hex: "30E3DF") ?? .clear
    }
    
    static var mbtiPurpleColor: Self {
        return self.init(hex: "C47BE4") ?? .clear
    }
    
    static var mbtiGreenColor: Self {
        return self.init(hex: "A8DF8E") ?? .clear
    }
    
    static var mbtiBlueColor: Self {
        return self.init(hex: "8CE4FF") ?? .clear
    }
    
    static var mbtiYellowColor: Self {
        return self.init(hex: "FFF57E") ?? .clear
    }
    
    static var likedColor: Self {
        return self.init(hex: "FF6D1F") ?? .clear
    }
    
    static var secondaryBackgroundColor: Self {
        return self.init(hex: "F9F8F6") ?? .clear
    }
    
    static var messageToColor: Self {
        return self.init(hex: "9CCFFF") ?? .clear 
    }
}
