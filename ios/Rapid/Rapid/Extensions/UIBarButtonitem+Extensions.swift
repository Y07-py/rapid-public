//
//  UIBarButtonitem+Extensions.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/18.
//

import Foundation
import UIKit

extension UIBarButtonItem {
    func setFont(font: UIFont?, forState state: UIControl.State) {
        guard font != nil else { return }
        self.setTitleTextAttributes([NSAttributedString.Key.font: font!], for: .normal)
    }
}
