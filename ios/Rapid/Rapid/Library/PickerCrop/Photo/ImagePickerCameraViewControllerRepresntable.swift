//
//  ImagePickerCameraViewControllerRepresntable.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/18.
//

import Foundation
import SwiftUI

struct ImagePickerCameraViewControllerRepresntable: UIViewControllerRepresentable {
    @EnvironmentObject private var imagePickerCameraRootViewModel: RootViewModel<ImagePickerCameraRoot>
    @Binding var selectedImage: UIImage
    @Binding var dismiss: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let pickerVC = UIImagePickerController()
        pickerVC.sourceType = .camera
        pickerVC.allowsEditing = false
        
        return pickerVC
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate {
        let parent: ImagePickerCameraViewControllerRepresntable
        
        init(_ parent: ImagePickerCameraViewControllerRepresntable) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.selectedImage = image
                    
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            self.parent.dismiss.toggle()
        }
    }
}

