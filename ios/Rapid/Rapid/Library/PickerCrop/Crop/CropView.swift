//
//  CropView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/18.
//

import Foundation
import SwiftUI
import SwiftyCrop


struct CropView: View {
    @Binding var selectedImage: UIImage
    
    let onPush: () -> Void
    let onPop: () -> Void
    
    let configuration = SwiftyCropConfiguration(texts: .init(cancelButton: "戻る", interactionInstructions: "", saveButton: "完了"),
                                                colors: .init(cancelButton: .black, saveButton: .black, background: .white))
    
    var body: some View {
        VStack {
            SwiftyCropView(imageToCrop: selectedImage, maskShape: .square, configuration: configuration) { croppedImage in
                if let croppedImage = croppedImage {
                    DispatchQueue.main.async {
                        self.selectedImage = croppedImage
                        onPush()
                    }
                } else {
                    onPop()
                }
            }
        }
    }
}
