//
//  ProfileImageSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/14.
//

import Foundation
import SwiftUI
import PopupView
import SDWebImageSwiftUI

struct ProfileImageSettingView: View {
    @EnvironmentObject private var settingRootViewModel: RootViewModel<ProfileLoginSettingRoot>
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    
    @State private var isShowSettingWindow: Bool = false
    @State private var isShowSecondSettingWindow: Bool = false
    @State private var mediaAccessItem: MediaAccessItem? = nil
    @State private var selectedIndex: Int = 0
    
    @StateObject private var locationViewModel = UserLocationViewModel.shared
    @State private var showLocationAlert: Bool = false
    
    private struct MediaAccessItem: Identifiable {
        let id = UUID()
        let type: MediaAccessRoot
        let image: UIImage?
        let index: Int
    }
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color.backgroundColor.ignoresSafeArea()
            
            // Background Glows
            ZStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(x: 120, y: -150)
                
                Circle()
                    .fill(Color.selectedColor.opacity(0.15))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: -120, y: 120)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 32) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Visuals")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.mainColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.mainColor.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Text("写真を登録しましょう")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(Color.primary)
                    
                    Text("あなたの雰囲気が伝わる写真を1枚以上設定してください。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // MARK: - Photo Management Card
                VStack(spacing: 24) {
                    HStack(alignment: .top, spacing: 16) {
                        // Main Photo Slot (Large)
                        PhotoSlot(
                            index: 0,
                            size: 200,
                            isMain: true,
                            isShowSettingWindow: $isShowSettingWindow,
                            isShowSecondSettingWindow: $isShowSecondSettingWindow,
                            selectedIndex: $selectedIndex
                        )
                        .environmentObject(profileLoginSettingViewModel)
                        
                        VStack(spacing: 16) {
                            // Sub Photo Slots
                            PhotoSlot(
                                index: 1,
                                size: 92,
                                isMain: false,
                                isShowSettingWindow: $isShowSettingWindow,
                                isShowSecondSettingWindow: $isShowSecondSettingWindow,
                                selectedIndex: $selectedIndex
                            )
                            .environmentObject(profileLoginSettingViewModel)
                            
                            PhotoSlot(
                                index: 2,
                                size: 92,
                                isMain: false,
                                isShowSettingWindow: $isShowSettingWindow,
                                isShowSecondSettingWindow: $isShowSecondSettingWindow,
                                selectedIndex: $selectedIndex
                            )
                            .environmentObject(profileLoginSettingViewModel)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.mainColor)
                            Text("メイン写真は顔がよくわかるものをおすすめします")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .baseShadow()
                
                Spacer()
                
                // MARK: - Navigation Buttons
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            settingRootViewModel.pop(1)
                            profileLoginSettingViewModel.progress -= 1
                        }
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.mainColor)
                            .frame(width: 64, height: 64)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .baseShadow()
                    }
                    
                    Button(action: {
                        checkLocationAndProceed()
                    }) {
                        Text("登録を完了する")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                LinearGradient(
                                    colors: [Color.mainColor, Color.mainColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .baseShadow()
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
        .alert("位置情報の利用について", isPresented: $showLocationAlert) {
            Button("許可して次へ") {
                locationViewModel.requestPermission()
                // Proceed anyway, fallback logic in LocationSearchLoginSettingView will handle it if slow
                proceedToNext()
            }
            Button("後で", role: .cancel) {
                proceedToNext()
            }
        } message: {
            Text("近くの人気スポットを表示するために、位置情報の利用を許可してください。許可しなくても、登録した地域からスポットを提案します。")
        }
        .popup(isPresented: $isShowSettingWindow) {
            photoActionPopup
        } customize: { item in
            item
                .type(.floater())
                .position(.bottom)
                .animation(.spring(response: 0.5, dampingFraction: 0.8))
                .allowTapThroughBG(false)
                .closeOnTapOutside(true)
                .closeOnTap(false)
                .backgroundColor(.black.opacity(0.4))
        }
        .popup(isPresented: $isShowSecondSettingWindow) {
            addPhotoActionPopup
        } customize: { item in
            item
                .type(.floater())
                .position(.bottom)
                .animation(.spring(response: 0.5, dampingFraction: 0.8))
                .allowTapThroughBG(false)
                .closeOnTapOutside(true)
                .closeOnTap(false)
                .backgroundColor(.black.opacity(0.4))
        }
        .fullScreenCover(item: $mediaAccessItem) { item in
            ProfileLoginMediaAccessRootView(viewType: item.type, editingImage: item.image, index: item.index)
                .environmentObject(profileLoginSettingViewModel)
        }
    }
    
    @ViewBuilder
    private var photoActionPopup: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("写真の操作")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.bottom, 4)
                
                Button(action: {
                    self.isShowSettingWindow = false
                    if selectedIndex < profileLoginSettingViewModel.selectedImages.count {
                        let image = profileLoginSettingViewModel.selectedImages[selectedIndex]
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.mediaAccessItem = MediaAccessItem(type: .edit, image: image, index: selectedIndex)
                        }
                    }
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.selectedColor.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "pencil.and.outline")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.selectedColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("写真を編集する")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black.opacity(0.8))
                            Text("フィルターや明るさを調整します")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.leading, 60)
                
                Button(action: {
                    self.isShowSettingWindow = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.mediaAccessItem = MediaAccessItem(type: .album, image: nil, index: selectedIndex)
                    }
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
                            Text("写真を変更する")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black.opacity(0.8))
                            Text("ライブラリから別の写真を選びます")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
    
    @ViewBuilder
    private var addPhotoActionPopup: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("写真を追加")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.bottom, 4)
                
                Button(action: {
                    self.isShowSecondSettingWindow = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.mediaAccessItem = MediaAccessItem(type: .album, image: nil, index: selectedIndex)
                    }
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
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.leading, 60)
                
                Button(action: {
                    self.isShowSecondSettingWindow = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.mediaAccessItem = MediaAccessItem(type: .camera, image: nil, index: selectedIndex)
                    }
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
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
    
    private func checkLocationAndProceed() {
        if locationViewModel.location != nil {
            proceedToNext()
        } else if locationViewModel.authorizationStatus == .notDetermined {
            showLocationAlert = true
        } else {
            // Already denied or allowed but no data yet, proceed with fallback
            proceedToNext()
        }
    }
    
    private func proceedToNext() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            profileLoginSettingViewModel.progress += 1
            settingRootViewModel.push(.locationSearch)
        }
    }
}

// MARK: - Photo Slot Component
fileprivate struct PhotoSlot: View {
    @EnvironmentObject var vm: ProfileLoginSettingViewModel
    let index: Int
    let size: CGFloat
    let isMain: Bool
    
    @Binding var isShowSettingWindow: Bool
    @Binding var isShowSecondSettingWindow: Bool
    @Binding var selectedIndex: Int
    
    var body: some View {
        Button(action: {
            selectedIndex = index
            if index < vm.selectedImages.count {
                isShowSettingWindow.toggle()
            } else {
                isShowSecondSettingWindow.toggle()
            }
        }) {
            ZStack {
                if index < vm.selectedImages.count {
                    Image(uiImage: vm.selectedImages[index])
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isMain ? Color.mainColor.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 2)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.4))
                        .frame(width: size, height: size)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: isMain ? 32 : 24))
                                    .foregroundStyle(Color.mainColor.opacity(0.6))
                                if isMain {
                                    Text("メイン写真")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.mainColor.opacity(0.6))
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                .foregroundStyle(Color.gray.opacity(0.3))
                        )
                }
                
                // Tag badge for Main
                if isMain {
                    Text("MAIN")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.mainColor)
                        .clipShape(Capsule())
                        .offset(x: -size/2 + 25, y: -size/2 + 15)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Media Access logic (adapted from ProfileThumbnailSettingView)
fileprivate enum MediaAccessRoot: Equatable {
    case edit
    case album
    case camera
}

fileprivate struct ProfileLoginMediaAccessRootView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    
    let initialViewType: MediaAccessRoot
    @StateObject private var mediaAccessRootViewModel: RootViewModel<MediaAccessRoot>
    let index: Int
    
    @State private var imageToEdit: UIImage? = nil
    
    init(viewType: MediaAccessRoot, editingImage: UIImage? = nil, index: Int) {
        self.initialViewType = viewType
        self.index = index
        self._mediaAccessRootViewModel = StateObject(wrappedValue: RootViewModel<MediaAccessRoot>(root: viewType))
        self._imageToEdit = State(initialValue: editingImage)
    }
    
    var body: some View {
        ZStack {
            RootViewController(rootViewModel: mediaAccessRootViewModel) { root in
                switch root {
                case .edit:
                    if let image = imageToEdit {
                        ProfileImageEditView(originalImage: image) { editedImage in
                            updateEditedImage(editedImage)
                        } onCancel: {
                            handleCancel()
                        }
                    } else {
                        Color.black.onAppear { handleCancel() }
                    }
                case .album:
                    PhotoAlbumView(isSelected: .constant(false)) { _, image in
                        self.imageToEdit = image
                        withAnimation(.spring()) {
                            mediaAccessRootViewModel.push(.edit)
                        }
                    } deselectedHandle: { _ in
                        dismiss()
                    }
                case .camera:
                    CameraPickerView { image in
                        self.imageToEdit = image
                        withAnimation(.spring()) {
                            mediaAccessRootViewModel.push(.edit)
                        }
                    } onCancel: {
                        dismiss()
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func handleCancel() {
        if mediaAccessRootViewModel.roots.count > 1 {
            withAnimation(.spring()) {
                mediaAccessRootViewModel.pop(1)
            }
        } else {
            dismiss()
        }
    }
    
    private func updateEditedImage(_ image: UIImage) {
        if index < profileLoginSettingViewModel.selectedImages.count {
            profileLoginSettingViewModel.selectedImages[index] = image
        } else {
            profileLoginSettingViewModel.selectedImages.append(image)
        }
        dismiss()
    }
}
