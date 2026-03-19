//
//  ChatRoomView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/04.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import Photos
import Photos

struct ChatRoomView: View {
    @EnvironmentObject private var chatRoomRootViewModel: RootViewModel<ChatRoomRoot>
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var chatRoomViewModel: ChatRoomViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @State private var messageScrollPosition: Int?
    
    @State private var message: String = ""
    @State private var albumImages: [Int: UIImage] = [:]
    
    @State private var bottomSpace: CGFloat = 100
    @FocusState private var focus: Bool
    @State private var showSendMessageButton: Bool = false
    @State private var textFieldBottomSpacce: CGFloat = 30
    @State private var uploadingImage: Bool = false
    
    @State private var selectAlbumView: Bool = false
    @State private var albumViewHeight: CGFloat = .zero
    
    @State private var isShowPlaceDetailWindow: Bool = false
    
    var body: some View {
        ZStack {
            Color.secondaryBackgroundColor.ignoresSafeArea()
            VStack(alignment: .center, spacing: .zero) {
                VStack(alignment: .center, spacing: .zero) {
                    headerView
                        .background(Color.secondaryBackgroundColor)
                        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                        .zIndex(2)
                        
                    if let selectedChatRoom = self.chatViewModel.selectedChatRoom {
                        statusBanner(chatRoom: selectedChatRoom)
                            .zIndex(1)
                            
                        ScrollViewReader { proxy in
                            ScrollView(.vertical) {
                                VStack(alignment: .center, spacing: 10) {
                                    ForEach(0..<selectedChatRoom.messages.count, id: \.self) { idx in
                                        VStack(alignment: .center, spacing: 10) {
                                            let message = selectedChatRoom.messages[idx]
                                            let preMessage = selectedChatRoom.messages[max(idx - 1, 0)]
                                            let betweenDay = computeBetweenMessageDate(message: message, preMessage: preMessage)
                                            
                                            if idx == 0 || betweenDay > 0 {
                                                HStack {
                                                    Spacer()
                                                    Text(messageDayFormat(date: message.createdAt))
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundStyle(.white)
                                                        .padding(.vertical, 5)
                                                        .padding(.horizontal, 10)
                                                        .background {
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .foregroundStyle(.gray.opacity(0.5))
                                                        }
                                                    Spacer()
                                                }
                                            }
                                            
                                            if message.fromUserId == self.profileViewModel.user?.user.id {
                                                ChatMessageFromView(message: message)
                                            } else {
                                                ChatMessageToView(message: message, preMessage: preMessage, toUser: selectedChatRoom.roomUser)
                                            }
                                        }
                                        .id(idx)
                                    }
                                    Spacer()
                                        .frame(height: bottomSpace)
                                        .id("bottom")
                                }
                                .padding(.top, 20)
                                .scrollTargetLayout()
                            }
                            .scrollIndicators(.hidden)
                            .onTapGesture {
                                self.focus = false
                                self.selectAlbumView = false
                                if self.albumViewHeight > 0 {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        self.albumViewHeight = 0
                                        self.textFieldBottomSpacce = 30
                                    }
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                                if let keyboardRect = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                                    self.bottomSpace = max(0, keyboardRect.height - 100)
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        self.albumViewHeight = keyboardRect.height
                                        self.textFieldBottomSpacce = 5
                                        proxy.scrollTo("bottom")
                                    }
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    if !self.selectAlbumView {
                                        self.bottomSpace = 100
                                        self.albumViewHeight = 0
                                        self.textFieldBottomSpacce = 30
                                    }
                                }
                            }
                            .scrollPosition(id: $messageScrollPosition)
                            .onChange(of: messageScrollPosition, { _, newValue in
                                if let newValue = newValue, newValue == 0 {
                                    self.chatRoomViewModel.reloadMessages()
                                }
                            })
                            .onAppear {
                                proxy.scrollTo("bottom")
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                
                VStack(alignment: .center, spacing: .zero) {
                    textFieldView
                    if selectAlbumView {
                        PhotoLibraryViewRepresentable(isSelected: $selectAlbumView) { idx, image in
                            self.albumImages[idx] = image
                            print("Selected album images: \(albumImages.count)")
                        } deselectedHandle: { idx in
                            self.albumImages.removeValue(forKey: idx)
                        }
                        .ignoresSafeArea()
                        .frame(height: albumViewHeight)
                    } else {
                        Rectangle()
                            .foregroundStyle(.white)
                            .frame(height: albumViewHeight)
                    }
                }
                .ignoresSafeArea()
            }
            .ignoresSafeArea(.keyboard)
            .ignoresSafeArea(edges: .bottom)
            .onChange(of: selectAlbumView) { _, newValue in
                if !newValue {
                    self.albumImages.removeAll()
                }
            }
            .fullScreenCover(isPresented: $isShowPlaceDetailWindow) {
                ChatRoomLocationListView()
                    .environmentObject(chatViewModel)
                    .environmentObject(chatRoomViewModel)
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.homeRootViewModel.pop(1)
                    self.chatViewModel.selectedChatRoom = nil
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.trailing, 10)
            }
            .buttonStyle(.plain)
            
            if let user = chatViewModel.selectedChatRoom?.roomUser {
                HStack(spacing: 12) {
                    if let profileImage = user.profileImages.first {
                        WebImage(url: profileImage.imageURL) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.2)).skelton(isActive: true)
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "person.fill").foregroundStyle(.gray)
                            }
                    }
                    
                    Text(user.user.userName ?? "No name")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                    
                    if chatRoomViewModel.isReported {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }
                }
            } else {
                Text("トーク")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
            }
            
            Spacer()
          
            Button(action: {
                chatRoomRootViewModel.push(.setting)
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }
    
    @ViewBuilder
    private func statusBanner(chatRoom: ChatRoomWithRecruitment) -> some View {
        let remaining = chatRoomViewModel.talkCount
        
        HStack {
            HStack(spacing: 6) {
                Image(systemName: remaining > 0 ? "envelope.fill" : "hand.thumbsup.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(remaining > 0 ? Color.mainColor : Color.thirdColor)
                
                if remaining > 0 {
                    Text("残り")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.gray)
                    Text("\(remaining)")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.mainColor)
                    Text("通で正式マッチ")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.gray)
                } else {
                    Text("マッチ成立！")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.thirdColor)
                }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowPlaceDetailWindow.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                    Text("スポット (\(chatRoom.places.count))")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.subFontColor.opacity(0.1))
                .foregroundStyle(Color.subFontColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.secondaryBackgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.gray.opacity(0.1)),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var textFieldView: some View {
        HStack(alignment: .center, spacing: .zero) {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    if self.focus {
                        self.selectAlbumView = true
                        self.focus = false
                    } else {
                        self.focus = true
                        self.selectAlbumView = false
                    }
                    
                    if !self.selectAlbumView {
                        self.albumViewHeight = 0
                        self.textFieldBottomSpacce = 30
                    }
                }
            }) {
                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 5)
            
            let albumCount = self.albumImages.count
            if albumCount == 0 || self.focus {
                HStack {
                    TextField("Aa", text: $message, axis: .vertical)
                        .focused($focus)
                        .onChange(of: message) { _, newValue in
                            if newValue.isEmpty {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.showSendMessageButton = false
                                }
                            } else {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.showSendMessageButton = true
                                }
                            }
                        }
                    Spacer()
                }
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundStyle(.gray.opacity(0.1))
                }
            } else {
                HStack {
                    Spacer()
                    Text("\(albumCount)枚選択中")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.blue)
                    Spacer()
                }
                .padding(10)
            }
            
            if showSendMessageButton || albumCount > 0 {
                Button(action: {
                    if self.focus {
                        self.chatRoomViewModel.sendMessage(text: message) {
                            self.message.removeAll()
                        }
                    } else {
                        let images = Array(self.albumImages.values)
                        
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.albumViewHeight = 0
                            self.textFieldBottomSpacce = 30
                            self.selectAlbumView = false
                        }
                        self.chatRoomViewModel.sendMessage(images: images) {

                            self.albumImages.removeAll()
                        }
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.blue)
                }
                .padding(.leading, 5)
            } else {
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(width: .zero, height: .zero)
                    .padding(.leading, 5)
            }
        }
        .padding(10)
        .padding(.bottom, textFieldBottomSpacce)
        .background(Color.white)
    }
    
    private func computeBetweenMessageDate(message: ChatMessage, preMessage: ChatMessage) -> Int {
        let calendar = Calendar.current
        
        let dateStart = calendar.startOfDay(for: preMessage.createdAt)
        let messageStart = calendar.startOfDay(for: message.createdAt)
        
        let components = calendar.dateComponents([.day], from: dateStart, to: messageStart)
        
        return abs(components.day ?? 0) 
    }
    
    private func messageDayFormat(date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        let currentYear = calendar.component(.year, from: .now)
        let targetYear = calendar.component(.year, from: date)
        
        if currentYear == targetYear {
            formatter.dateFormat = "M/d"
        } else {
            formatter.dateFormat = "yyyy/M/d"
        }
        
        return formatter.string(from: date)
    }
}

fileprivate struct ChatMessageFromView: View {
    @EnvironmentObject private var chatRoomViewModel: ChatRoomViewModel
    
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            Spacer()
            Text(messageTimeFormat(date: message.updatedAt))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.gray.opacity(0.8))
            if message.contextType == "text" {
                Text(message.context)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                    .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
            } else if message.contextType == "image" {
                if let imageURL = URL(string: message.context) {
                    WebImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .clipped()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 20)
                            .frame(width: 200, height: 300)
                            .foregroundStyle(.gray.opacity(0.8))
                            .skelton(isActive: true)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                    .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
                    
                } else {
                    if let image = message.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .clipped()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func messageTimeFormat(date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

fileprivate struct ChatMessageToView: View {
    let message: ChatMessage
    let preMessage: ChatMessage
    let toUser: RapidUserWithProfile
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            let sameMinute = self.sameMessageMinute(date1: message.createdAt, date2: preMessage.createdAt) && message.toUserId == preMessage.toUserId
            if sameMinute {
                Circle()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.clear)
            } else {
                if let profileImage = toUser.profileImages.first {
                    WebImage(url: profileImage.imageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .clipped()
                    } placeholder: {
                        Circle()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(.gray.opacity(0.8))
                            .skelton(isActive: true)
                    }
                } else {
                    Image("nontitle_cover")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .clipped()
                }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                if sameMinute {
                    Text(toUser.user.userName ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.8))
                }
                
                HStack(alignment: .bottom, spacing: 5) {
                    if message.contextType == "text" {
                        Text(message.context)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.black.opacity(0.8))
                            .padding(10)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .foregroundStyle(Color.messageToColor)
                            }
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                            .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
                    } else if message.contextType == "image" {
                        if let imageURL = URL(string: message.context) {
                            WebImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: 200, maxHeight: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .clipped()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 20)
                                    .frame(maxWidth: 200, maxHeight: 300)
                                    .foregroundStyle(.gray.opacity(0.8))
                                    .skelton(isActive: true)
                            }
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                            .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
                            
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .frame(maxWidth: 200, maxHeight: 300)
                                .foregroundStyle(.gray.opacity(0.8))
                                .skelton(isActive: true)
                                .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                                .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
                        }
                    }
                    Text(messageTimeFormat(date: message.updatedAt))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.gray.opacity(0.8))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    private func sameMessageMinute(date1: Date, date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, equalTo: date2, toGranularity: .minute)
    }
    
    private func messageTimeFormat(date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

final class CustomPhotoPickerViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    private var collectionView: UICollectionView!
    private var fetchResult: PHFetchResult<PHAsset>?
    private let imageManager = PHCachingImageManager()
    
    var onSelected: ((Int, UIImage) -> Void)?
    var onDeselected: ((Int) -> Void)?
    
    // We can store a maximum number of selection as well or just toggle
    private var selectedIndices: Set<Int> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .white
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.contentInsetAdjustmentBehavior = .never
        
        view.addSubview(collectionView)
        
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            if status == .authorized || status == .limited {
                self.fetchPhotos()
            }
        }
    }
    
    private func fetchPhotos() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResult?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        guard let asset = fetchResult?.object(at: indexPath.item) else { return cell }
        
        cell.representedAssetIdentifier = asset.localIdentifier
        let targetSize = CGSize(width: 300, height: 300)
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
            if cell.representedAssetIdentifier == asset.localIdentifier {
                cell.imageView.image = image
            }
        }
        
        cell.toggleSelection(selectedIndices.contains(indexPath.item))
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 4) / 3
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let index = indexPath.item
        guard let asset = fetchResult?.object(at: index) else { return }
        
        if selectedIndices.contains(index) {
            // Deselect
            selectedIndices.remove(index)
            if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
                cell.toggleSelection(false)
            }
            onDeselected?(index)
        } else {
            // Single selection: deselect previously selected items
            for oldIndex in selectedIndices {
                let oldIndexPath = IndexPath(item: oldIndex, section: 0)
                if let oldCell = collectionView.cellForItem(at: oldIndexPath) as? PhotoCell {
                    oldCell.toggleSelection(false)
                }
                onDeselected?(oldIndex)
            }
            selectedIndices.removeAll()
            
            // Select the new item
            selectedIndices.insert(index)
            if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
                cell.toggleSelection(true)
            }
            
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFill, options: options) { [weak self] image, info in
                if let image = image {
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if !isDegraded {
                        DispatchQueue.main.async {
                            self?.onSelected?(index, image)
                        }
                    }
                }
            }
        }
    }
}

final class PhotoCell: UICollectionViewCell {
    let imageView = UIImageView()
    let highlightOverlay = UIView()
    var representedAssetIdentifier: String?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(imageView)
        
        highlightOverlay.frame = contentView.bounds
        highlightOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        highlightOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        highlightOverlay.layer.borderWidth = 3
        highlightOverlay.layer.borderColor = UIColor(Color.thirdColor).cgColor
        highlightOverlay.isHidden = true
        contentView.addSubview(highlightOverlay)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func toggleSelection(_ isSelected: Bool) {
        highlightOverlay.isHidden = !isSelected
    }
}

fileprivate struct PhotoLibraryViewRepresentable: UIViewControllerRepresentable {
    @Binding var isSelected: Bool
    var selectedHandle: (Int, UIImage) -> ()
    var deselectedHandle: (Int) -> ()
    
    func makeUIViewController(context: Context) -> CustomPhotoPickerViewController {
        let vc = CustomPhotoPickerViewController()
        vc.onSelected = { index, image in
            DispatchQueue.main.async {
                self.isSelected = true
                self.selectedHandle(index, image)
            }
        }
        vc.onDeselected = { index in
            DispatchQueue.main.async {
                self.deselectedHandle(index)
            }
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CustomPhotoPickerViewController, context: Context) {}
}

extension Color {
    func uiColor() -> UIColor {
        if #available(iOS 14.0, *) {
            return UIColor(self)
        }
        return .white
    }
}

