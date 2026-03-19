//
//  ImageFilterViewControllerRepresentable.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/16.
//

import Foundation
import SwiftUI

struct ImageFilterViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage
    let pushRoot: () -> Void
    let popRoot: () -> Void
    let fromCamera: Bool
    
    func makeUIViewController(context: Context) -> ImageFilterViewController {
        let viewController = ImageFilterViewController(inputPhoto: PickerCropPhoto(image: selectedImage, fromCamera: fromCamera),
                                                       isFromSelectionVC: true)
        viewController.didSave = { imagePhoto in
            switch imagePhoto {
            case .photo(let photo):
                DispatchQueue.main.async {
                    self.selectedImage = photo.modifiedImage ?? photo.originalImage
                }
            }
            pushRoot()
        }
        
        viewController.didCancel = {
            popRoot()
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ImageFilterViewController, context: Context) {}
}
