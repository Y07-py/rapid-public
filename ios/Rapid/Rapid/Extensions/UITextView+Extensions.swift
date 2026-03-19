//
//  UITextView+Extensions.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/14.
//

import Foundation
import UIKit

extension UITextView {
    func updateFormattedText() {
        // Keep cursol position when editing.
        
        let selectedRange = self.selectedTextRange
        let fullRange = NSRange(location: 0, length: self.text.utf16.count)
        
        let attributedString = NSMutableAttributedString(string: self.text)
        
        attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        attributedString.addAttribute(.font, value: self.font ?? .systemFont(ofSize: 16), range: fullRange)
        
        // # character color change default color to blue.
        let regex = try? NSRegularExpression(pattern: "#[^\\s#]+", options: [])
        let matches = regex?.matches(in: self.text, options: [], range: fullRange)
        
        matches?.forEach { match in
            attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
        }
        
        if !self.attributedText.isEqual(to: attributedString) {
            self.attributedText = attributedString
            self.selectedTextRange = selectedRange
        }
    }
    
    func addPlaceHolder(placeHolder: String) {
        let label = UILabel()
        label.text = placeHolder
        label.font = self.font
        label.textColor = .placeholderText
        label.tag = 100
        
        self.addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 5)
        ])
    }
    
    func hiddenPlaceHolder() {
        self.viewWithTag(100)?.isHidden = true
    }
    
    func showPlaceHolder() {
        self.viewWithTag(100)?.isHidden = false
    }
}
