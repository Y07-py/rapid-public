//
//  PhotoAlbumView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/08.
//

import Foundation
import SwiftUI
import PhotosUI

public struct PhotoAlbumView: UIViewControllerRepresentable {
    @Binding var isSelected: Bool
    
    // Callback implementation consistent with previous version
    private var selectedHandle: (Int, UIImage) -> ()
    private var deselectedHandle: (Int) -> ()
    
    public init(
        isSelected: Binding<Bool>,
        selectedHandle: @escaping (Int, UIImage) -> (),
        deselectedHandle: @escaping (Int) -> ()
    ) {
        self._isSelected = isSelected
        self.selectedHandle = selectedHandle
        self.deselectedHandle = deselectedHandle
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        // 1 means single selection, 0 means unlimited. Matching original intent of profile photo.
        configuration.selectionLimit = 1 
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    public class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoAlbumView
        
        init(_ parent: PhotoAlbumView) {
            self.parent = parent
        }
        
        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // results will be empty if user cancelled
            if results.isEmpty {
                // Return to whatever view presented us (likely handled by RootViewModel in the caller)
                parent.deselectedHandle(-1) // Signal cancellation
                return
            }
            
            // Handle image selection (matching the single selection limit)
            let itemProvider = results[0].itemProvider
            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                itemProvider.loadObject(ofClass: UIImage.self) { [weak self] (image, error) in
                    guard let self = self, let uiImage = image as? UIImage else { return }
                    
                    DispatchQueue.main.async {
                        withAnimation {
                            self.parent.isSelected = true
                        }
                        // TLPhotoPicker's callback used indices; for PHPicker selection, 
                        // we'll pass 0 as the index as per single selection.
                        self.parent.selectedHandle(0, uiImage)
                    }
                }
            }
        }
    }
}
