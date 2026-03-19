//
//  TextEditorView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/13.
//

import Foundation
import SwiftUI

public struct TextEditorView: UIViewRepresentable {
    @Binding var text: String
    @Binding var focus: Bool
    
    let placeHolder: String
    var color:  UIColor? = UIColor(hex: "F3F2EC")
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Proto type.
    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = color
        textView.text = text
        
        if text.isEmpty {
            textView.addPlaceHolder(placeHolder: placeHolder)
        }
        
        return textView
    }
    
    public func updateUIView(_ uiView: UITextView, context: Context) {
        if focus {
            uiView.becomeFirstResponder()
        } else {
            uiView.resignFirstResponder()
        }
    }
    
    public class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextEditorView
        
        init(_ parent: TextEditorView) {
            self.parent = parent
        }
        
        public func textViewDidChange(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.showPlaceHolder()
            } else {
                textView.hiddenPlaceHolder()
            }
            
            self.parent.text = textView.text
            textView.updateFormattedText()
        }
    }
}

public struct TextEditorStaticView: UIViewRepresentable {
    @Binding var text: String
    
    let placeHolder: String
    var color: UIColor? = UIColor(hex: "F3F2EC")
    
    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = color
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = true
        
        if text.isEmpty {
            textView.addPlaceHolder(placeHolder: placeHolder)
        }
        
        return textView
    }
    
    public func updateUIView(_ uiView: UITextView, context: Context) {
        if text.isEmpty {
            uiView.showPlaceHolder()
        } else {
            uiView.hiddenPlaceHolder()
        }
        
        uiView.text = text
        uiView.updateFormattedText()
    }
}
