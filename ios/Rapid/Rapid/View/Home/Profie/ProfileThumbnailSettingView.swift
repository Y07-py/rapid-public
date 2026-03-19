//
//  ProfileImageSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/25.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import PopupView

struct ProfileThumbnailSettingView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @Binding var isShowWindow: Bool
    
    @State private var isShowSettingWindow: Bool = false
    @State private var isShowSecondSettingWindow: Bool = false
    @State private var mediaAccessItem: MediaAccessItem? = nil
    @State private var selectedProfileImage: UserProfileImage? = nil
    
    private struct MediaAccessItem: Identifiable {
        let id = UUID()
        let type: MediaAccessRoot
        let image: UIImage?
        let index: Int
    }
    
    private let maximumProfileImageCount: Int = 6 // Standard 2x3 or 3x2 grid
    
    private var cardWidth: CGFloat {
        (UIScreen.main.bounds.width - 52) / 3
    }
    
    private var cardHeight: CGFloat {
        cardWidth * 1.35
    }
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            VStack(alignment: .center, spacing: .zero) {
                headerView
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .center, spacing: 24) {
                        // Info Section
                        VStack(spacing: 8) {
                            Text("プロフィール写真")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.black.opacity(0.8))
                            
                            Text("最大\(maximumProfileImageCount)枚まで登録できます")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.gray)
                        }
                        .padding(.top, 20)
                        
                        // Grid Section
                        LazyVGrid(columns: [
                            GridItem(.fixed(cardWidth), spacing: 12),
                            GridItem(.fixed(cardWidth), spacing: 12),
                            GridItem(.fixed(cardWidth), spacing: 12)
                        ], spacing: 12) {
                            let allImages = profileViewModel.userProfileImages
                            let filteredImagesWithIndex = allImages.enumerated().compactMap { (index, img) -> (Int, UserProfileImage)? in
                                if profileViewModel.imagesToBeDeleted.contains(where: { $0.value.id == img.id }) {
                                    return nil
                                }
                                return (index, img)
                            }
                            
                            ForEach(0..<maximumProfileImageCount, id: \.self) { gridIdx in
                                if gridIdx < filteredImagesWithIndex.count {
                                    let (originalIdx, image) = filteredImagesWithIndex[gridIdx]
                                    imageCard(image: image, at: originalIdx)
                                } else {
                                    profileImageSettingCardView
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        if profileViewModel.hasChanges {
                            // Save Button
                            Button(action: {
                                profileViewModel.uploadProfileImages()
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.isShowWindow.toggle()
                                }
                            }) {
                                Text("変更を確定する")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(Color.selectedColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.selectedColor.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Tips Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("💡 良い写真のポイント")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black.opacity(0.7))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                tipRow(text: "顔がはっきりと写っている")
                                tipRow(text: "明るい場所で撮影されている")
                                tipRow(text: "あなたの雰囲気が伝わる写真")
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondaryBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 16)
                        
                        Spacer().frame(height: 100)
                    }
                }
            }
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
            ProfileMediaAccessRootView(viewType: item.type, editingImage: item.image, index: item.index)
                .environmentObject(profileViewModel)
        }
        .onAppear {
            profileViewModel.syncProfileImagesWithServer()
        }
        .onDisappear {
            profileViewModel.refreshWhenDisappear()
        }
    }
    
    @ViewBuilder
    private var photoActionPopup: some View {
        VStack(spacing: 20) {
            // Indicator
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
                    guard let profileImage = selectedProfileImage else { return }
                    
                    let completion: (UIImage?) -> Void = { image in
                        guard let image = image else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if let index = profileViewModel.userProfileImages.firstIndex(where: { $0.id == profileImage.id }) {
                                self.mediaAccessItem = MediaAccessItem(type: .edit, image: image, index: index)
                            }
                        }
                    }
                    
                    if let imageData = profileImage.image, let image = UIImage(data: imageData) {
                        completion(image)
                    } else if let url = profileImage.imageURL {
                        SDWebImageManager.shared.loadImage(
                            with: url,
                            options: .highPriority,
                            progress: nil
                        ) { image, data, error, cacheType, finished, url in
                            completion(image)
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
                    guard let profileImage = selectedProfileImage else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let index = profileViewModel.userProfileImages.firstIndex(where: { $0.id == profileImage.id }) {
                            self.mediaAccessItem = MediaAccessItem(type: .album, image: nil, index: index)
                        }
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
                        self.mediaAccessItem = MediaAccessItem(type: .album, image: nil, index: profileViewModel.userProfileImages.count)
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
                        self.mediaAccessItem = MediaAccessItem(type: .camera, image: nil, index: profileViewModel.userProfileImages.count)
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
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center, spacing: .zero) {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowWindow.toggle()
                }
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.black.opacity(0.8))
            }
            .padding(.leading, 12)
            
            Spacer()
            
            Text("プロフィール写真の設定")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
            
            Spacer()
            
            // Dummy for balance
            Rectangle()
                .frame(width: 44, height: 44)
                .foregroundStyle(.clear)
                .padding(.trailing, 12)
        }
        .padding(.vertical, 8)
        .background(Color.backgroundColor)
    }
    
    @ViewBuilder
    private func imageCard(image: UserProfileImage, at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let imageData = image.image, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if let url = image.imageURL {
                    if let token = image.token {
                        WebImage(url: url, context: [
                            .downloadRequestModifier: SDWebImageDownloaderRequestModifier(headers:[
                                "Authorization": "Bearer \(token)"
                            ])
                        ]) { view in
                            view
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .foregroundStyle(.gray.opacity(0.8))
                                .skelton(isActive: true)
                        }
                    } else {
                        WebImage(url: url) { view in
                            view
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .foregroundStyle(.gray.opacity(0.8))
                                .skelton(isActive: true)
                        }
                    }
                } else {
                    Rectangle()
                        .foregroundStyle(.gray.opacity(0.8))
                        .skelton(isActive: true)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .opacity(image.isUnderReview ? 0.7 : 1.0)
            .overlay {
                if image.isUnderReview {
                    ZStack {
                        Rectangle()
                            .fill(.black.opacity(0.3))
                            .background(.ultraThinMaterial)
                        
                        VStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 20))
                            Text("審査中")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .onTapGesture {
                self.selectedProfileImage = image
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowSettingWindow.toggle()
                }
            }
            
            Button(action: {
                withAnimation(.spring()) {
                    profileViewModel.imagesToBeDeleted[index] = image
                }
            }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 0.5))
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(8)
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    @ViewBuilder
    private var profileImageSettingCardView: some View {
        Button(action: {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.isShowSecondSettingWindow.toggle()
            }
        }) {
            ZStack {
                // Liquid Glass Background blobs
                Circle()
                    .fill(Color.mainColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .blur(radius: 20)
                    .offset(x: -15, y: -25)
                
                Circle()
                    .fill(Color.likedColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .blur(radius: 15)
                    .offset(x: 15, y: 25)

                // The Glass Card
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.15))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.6), .clear, .white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                
                // Reflection highlight
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .mask(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(lineWidth: 10)
                            .blur(radius: 10)
                    )

                // Plus Icon
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.mainColor.gradient)
                            .frame(width: 38, height: 38)
                            .shadow(color: Color.mainColor.opacity(0.3), radius: 6, x: 0, y: 3)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private func tipRow(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.mainColor)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.black.opacity(0.6))
        }
    }
}

fileprivate enum MediaAccessRoot: Equatable {
    case edit
    case album
    case camera
}

fileprivate struct ProfileMediaAccessRootView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
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
                            // TODO: Handle upload (Supabase)
                            updateEditedImage(editedImage)
                        } onCancel: {
                            handleCancel()
                        }
                    } else {
                        Color.black.onAppear { handleCancel() }
                    }
                case .album:
                    PhotoAlbumView(isSelected: .constant(false)) { index, image in
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
        let userProfileImage = UserProfileImage(image: image)
        profileViewModel.updateProfileImage(idx: index, image: userProfileImage)
        dismiss()
    }
}
