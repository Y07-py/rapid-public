//
//  ImagePickerCameraRootView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/15.
//

import Foundation
import SwiftUI

enum ImagePickerCameraRoot: Equatable {
    case camera
    case filter
    case crop
}

struct ImagePickerCameraRootView: View {
    @StateObject private var imagePickerCameraRootViewModel: RootViewModel<ImagePickerCameraRoot> = .init(root: .camera)
    @Binding var selectedImage: UIImage
    @Binding var isPresented: Bool
    
    var body: some View {
        RootViewController(rootViewModel: imagePickerCameraRootViewModel) { root in
            switch root {
            case .camera:
                ImagePickerCameraViewControllerRepresntable(selectedImage: $selectedImage, dismiss: $isPresented)
            case .filter:
                ImageFilterViewControllerRepresentable(selectedImage: $selectedImage, pushRoot: {
                    imagePickerCameraRootViewModel.push(.crop)
                }, popRoot: {
                    imagePickerCameraRootViewModel.pop(1)
                }, fromCamera: true)
            case .crop:
                CropView(selectedImage: $selectedImage) {
                    withAnimation {
                        isPresented.toggle()
                    }
                } onPop: {
                    imagePickerCameraRootViewModel.pop(1)
                }
            }
        }
        .environmentObject(imagePickerCameraRootViewModel)
        .ignoresSafeArea()
    }
}

