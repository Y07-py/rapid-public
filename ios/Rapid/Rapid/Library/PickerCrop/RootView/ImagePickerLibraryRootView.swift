//
//  ImagePickerLibraryRootView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/15.
//

import Foundation
import SwiftUI
import PhotosUI

enum ImagePickerLibraryRoot: Equatable {
    case library
    case filter
    case crop
}

struct ImagePickerLibraryRootView: View {
    @StateObject private var imagePickerLibraryRootViewModel: RootViewModel<ImagePickerLibraryRoot> = .init(root: .library)
    @Binding var selectedImage: UIImage
    @Binding var isPresented: Bool
    
    var body: some View {
        RootViewController(rootViewModel: imagePickerLibraryRootViewModel) { root in
            switch root {
            case .library:
                ImagePickerLibraryView(selectedImage: $selectedImage, dismiss: $isPresented)
            case .filter:
                ImageFilterViewControllerRepresentable(selectedImage: $selectedImage, pushRoot: {
                    imagePickerLibraryRootViewModel.push(.crop)
                }, popRoot: {
                    imagePickerLibraryRootViewModel.pop(1)
                }, fromCamera: false)
            case .crop:
                CropView(selectedImage: $selectedImage) {
                    withAnimation {
                        isPresented.toggle()
                    }
                } onPop: {
                    imagePickerLibraryRootViewModel.pop(1)
                }
            }
        }
        .environmentObject(imagePickerLibraryRootViewModel)
        .ignoresSafeArea()
    }
}

struct ImagePickerLibraryView: View {
    @EnvironmentObject private var imagePickerLibraryRootViewModel: RootViewModel<ImagePickerLibraryRoot>
    @Binding var selectedImage: UIImage
    @Binding var dismiss: Bool
    @State private var isSelected: Bool = false
    
    var body: some View {
        ImagePickerLibraryViewControllerRepresentable(selectedImage: $selectedImage, dismiss: $dismiss)
            .overlay(alignment: .topTrailing) {
                Button(action: {
                    if isSelected {
                        imagePickerLibraryRootViewModel.push(.filter)
                    }
                }) {
                    Text("完了")
                        .font(.callout)
                        .foregroundStyle(isSelected ? Color.blue : Color.gray)
                }
                .padding(.trailing, 20)
                .padding(.top, 10)
            }
            .onChange(of: selectedImage) { _, _ in
                withAnimation {
                    isSelected = true
                }
            }
    }
}
