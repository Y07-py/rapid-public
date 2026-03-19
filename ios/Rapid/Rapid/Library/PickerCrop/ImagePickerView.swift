//
//  ImagePickerViewController.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/15.
//

import Foundation
import SwiftUI

struct ImagePickerView: View {
    @State private var isLibrary: Bool = false
    @State private var isCamera: Bool = false
    @Binding var selectedImage: UIImage
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.secondaryBackgroundColor.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Indicator
                Capsule()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("写真を追加")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                        .padding(.horizontal, 24)
                    
                    VStack(spacing: 0) {
                        // Library Button
                        Button(action: {
                            isLibrary.toggle()
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.selectedColor.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(Color.selectedColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ライブラリから選択")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.black.opacity(0.8))
                                    Text("保存されている写真を使用します")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .padding(.leading, 84)
                        
                        // Camera Button
                        Button(action: {
                            isCamera.toggle()
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.selectedColor.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(Color.selectedColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("カメラで撮影")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.black.opacity(0.8))
                                    Text("今すぐ写真を撮影します")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .fullScreenCover(isPresented: $isLibrary) {
            ImagePickerLibraryRootView(selectedImage: $selectedImage, isPresented: $isPresented)
        }
        .fullScreenCover(isPresented: $isCamera) {
            ImagePickerCameraRootView(selectedImage: $selectedImage, isPresented: $isPresented)
        }
    }
}
