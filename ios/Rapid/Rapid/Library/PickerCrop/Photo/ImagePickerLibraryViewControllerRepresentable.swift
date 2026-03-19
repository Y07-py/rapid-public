//
//  ImagePickerLibraryViewControllerRepresentable.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/18.
//

import Foundation
import SwiftUI
import PhotosUI

struct ImagePickerLibraryViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage
    @Binding var dismiss: Bool
    
    private let logger = Logger.shared
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        
        let pickerVC = PHPickerViewController(configuration: config)
        pickerVC.delegate = context.coordinator
        return pickerVC
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePickerLibraryViewControllerRepresentable
        
        init(_ parent: ImagePickerLibraryViewControllerRepresentable) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            if results.isEmpty {
                self.parent.dismiss.toggle()
                return
            }
            
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }
            
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let error = error {
                    self?.parent.logger.warning("⚠️ Failed to load image object.: \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.parent.selectedImage = object as! UIImage
                }
            }
        }
    }
}

