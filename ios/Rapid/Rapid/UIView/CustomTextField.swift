//
//  CustomTextField.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/10.
//

import Foundation
import SwiftUI

struct CustomTextField: UIViewRepresentable {
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let alignmentType: CTTextAlignment
    let fontSize: CGFloat
    var onBackspaceCallback: (() -> Void)?
    
    init(
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        alignmentType: CTTextAlignment = .left,
        fontSize: CGFloat = 32,
        onBackspaceCallback: (() -> Void)? = nil
    ) {
        self._text = text
        self.keyboardType = keyboardType
        self.alignmentType = alignmentType
        self.fontSize = fontSize
        self.onBackspaceCallback = onBackspaceCallback
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> EnhancedUITextField {
        let textField = EnhancedUITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.keyboardType = keyboardType
        textField.font = .systemFont(ofSize: fontSize)
        textField.textAlignment = .init(alignmentType)
        
        return textField
    }
    
    func updateUIView(_ uiView: EnhancedUITextField, context: Context) {
        uiView.text = text
        uiView.onBackspace = onBackspaceCallback
    }
    
    class EnhancedUITextField: UITextField {
        var onBackspace: (() -> Void)?
        
        override init(frame: CGRect) {
            onBackspace = nil
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError()
        }
        
        override func deleteBackward() {
            onBackspace?()
            super.deleteBackward()
        }
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: CustomTextField
        
        init(_ parent: CustomTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.text = textField.text ?? ""
            }
        }
    }
}
