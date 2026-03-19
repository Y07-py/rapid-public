//
//  VoiceChatDetailView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/20.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import PopupView
import LinkPresentation
import CoreLocation
import Lottie

fileprivate enum DetailWindowType: Hashable {
    case profile
    case location
}

struct VoiceChatDetailView: View {
    @EnvironmentObject private var voiceChatViewModel: VoiceChatViewModel
    @EnvironmentObject private var chatViewModel: ChatViewModel
    
    @State private var selectedTabIdx: Int = 0
    @State private var detailWindowType: DetailWindowType = .profile
    @State private var liked: Bool = false
    @State private var likeAnimation: Bool = false
    
    @Namespace private var namespace
    
    @Binding var isShowDetailView: Bool
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            VStack(alignment: .center, spacing: .zero) {
                switch detailWindowType {
                case .profile:
                    VoiceChatUserProfileView()
                        .environmentObject(voiceChatViewModel)
                case .location:
                    VoiceChatLocationView()
                        .environmentObject(voiceChatViewModel)
                }
            }
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                tabHeaderView
            }
            .overlay(alignment: .bottom) {
                if let room = voiceChatViewModel.selectedVoiceChatRoom {
                    Button(action: {
                        if !voiceChatViewModel.isEnableTalk {
                            chatViewModel.isShowPermissionFlow = true
                        } else {
                            withAnimation {
                                self.liked.toggle()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                self.voiceChatViewModel.sendLikeToVoiceChatRoom(room: room)
                                self.liked.toggle()
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: room.checked ? "checkmark.seal.fill" : "hand.thumbsup.fill")
                                .font(.system(size: 20, weight: .bold))
                            
                            Text(room.checked ? "いいね済み" : "いいね")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            room.checked ? 
                            Color.likedColor : 
                            Color.mainColor
                        )
                        .clipShape(Capsule())
                        .shadow(color: (room.checked ? Color.likedColor : Color.mainColor).opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 25)
                    .disabled(room.checked)
                    .popup(isPresented: $liked) {
                        goodThumbsupView
                    } customize: { view in
                        view
                            .type(.floater())
                            .appearFrom(.none)
                            .position(.center)
                            .animation(.bouncy)
                            .backgroundColor(Color.black.opacity(0.4))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var tabHeaderView: some View {
        HStack {
            Button(action: {
                withAnimation {
                    self.isShowDetailView = false
                }
            }) {
                Circle()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.ultraThinMaterial)
                    .overlay {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
            
            Spacer()
            
            HStack(spacing: 0) {
                Text("プロフィール")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background {
                        Capsule()
                            .fill(Color.mainColor)
                    }
            }
            .padding(4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            
            Spacer()
            
            // Empty placeholder for balance
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
        .background {
            LinearGradient(
                colors: [.black.opacity(0.5), .black.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    private var goodThumbsupView: some View {
        VStack(alignment: .center, spacing: 0) {
            LottieView(animation: .named("like.json"))
                .playbackMode(.playing(.toProgress(1, loopMode: .playOnce)))
                .frame(width: 100, height: 100)
            
            Text("いいねしました！")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.subFontColor)
                .padding(.top, -10)
            
            Text("残りポイント 100")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.black.opacity(0.4))
                .padding(.top, 4)
                .padding(.bottom, 16)
        }
        .frame(width: 160, height: 160)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .baseShadow()
    }
}

fileprivate struct VoiceChatUserProfileView: View {
    @EnvironmentObject private var voiceChatViewModel: VoiceChatViewModel
    
    @State private var scrollIdx: Int? = 0
    @State private var mbtiThumbnailURL: URL? = nil
    
    var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: .zero) {
                ScrollView(.vertical) {
                    VStack(alignment: .center, spacing: .zero) {
                        if let room = voiceChatViewModel.selectedVoiceChatRoom {
                            // MARK: - Image Paging
                            ZStack(alignment: .bottom) {
                                ScrollView(.horizontal) {
                                    HStack(alignment: .center, spacing: .zero) {
                                        ForEach(Array(room.profile.profileImages.enumerated()), id: \.element.id) { idx, image in
                                            WebImage(url: image.imageURL) { view in
                                                view
                                                    .resizable()
                                                    .scaledToFill()
                                            } placeholder: {
                                                Rectangle()
                                                    .foregroundStyle(.gray.opacity(0.1))
                                                    .skelton(isActive: true)
                                            }
                                            .containerRelativeFrame(.horizontal)
                                            .frame(height: 520)
                                            .clipped()
                                            .id(idx)
                                        }
                                    }
                                    .scrollTargetLayout()
                                }
                                .scrollIndicators(.hidden)
                                .scrollTargetBehavior(.paging)
                                .scrollPosition(id: $scrollIdx)
                                
                                if room.profile.profileImages.count > 1 {
                                    HStack(spacing: 6) {
                                        ForEach(0..<room.profile.profileImages.count, id: \.self) { idx in
                                            Capsule()
                                                .frame(width: idx == scrollIdx ? 20 : 6, height: 6)
                                                .foregroundStyle(idx == scrollIdx ? .white : .white.opacity(0.4))
                                                .animation(.spring(response: 0.3), value: scrollIdx)
                                        }
                                    }
                                    .padding(.bottom, 25)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 30) {
                                // MARK: - Basic Info Header
                                let user = room.profile.user
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .bottom, spacing: 10) {
                                        Text(user.userName ?? "No name")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundStyle(.black.opacity(0.85))
                                        
                                        Text("\(user.birthDate?.computeAge() ?? 0)歳")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.black.opacity(0.6))
                                            .padding(.bottom, 2)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.selectedColor)
                                        
                                        Text(user.residence ?? "居住地未設定")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 25)
                                
                                // Introduction
                                if let introduction = user.introduction {
                                    VStack(alignment: .leading, spacing: 15) {
                                        customSectionHeader(title: "自己紹介", icon: "quote.opening")
                                        
                                        Text(introduction)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.black.opacity(0.75))
                                            .lineSpacing(6)
                                            .padding(20)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.secondaryBackgroundColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
                                    }
                                    .padding(.horizontal, 24)
                                }
                                
                                // Detailed Profile
                                VStack(alignment: .leading, spacing: 15) {
                                    customSectionHeader(title: "プロフィール詳細", icon: "person.text.rectangle")
                                    
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                        if let height = user.height {
                                            attributeGridItem(title: "身長", value: "\(height)cm", icon: "ruler")
                                        }
                                        if let bodyType = user.bodyType {
                                            attributeGridItem(title: "体型", value: bodyType, icon: "figure.arms.open")
                                        }
                                        if let bloodType = user.bloodType {
                                            attributeGridItem(title: "血液型", value: "\(bloodType)型", icon: "drop.fill")
                                        }
                                        if let profession = user.profession {
                                            attributeGridItem(title: "職業", value: profession, icon: "briefcase.fill")
                                        }
                                        if let income = user.income {
                                            attributeGridItem(title: "年収", value: income, icon: "yensign.circle.fill")
                                        }
                                        if let childStatus = user.childStatus {
                                            attributeGridItem(title: "子ども", value: childStatus, icon: "person.2.fill")
                                        }
                                        if let holidayType = user.holidayType {
                                            attributeGridItem(title: "休日", value: holidayType, icon: "calendar")
                                        }
                                        if let smokingFrequency = user.smokingFrequency {
                                            attributeGridItem(title: "喫煙", value: smokingFrequency, icon: "smoke.fill")
                                        }
                                        if let drinkingFrequency = user.drinkingFrequency {
                                            attributeGridItem(title: "お酒", value: drinkingFrequency, icon: "wineglass.fill")
                                        }
                                        if let thoughtMarriage = user.thoughtMarriage {
                                            attributeGridItem(title: "結婚意思", value: thoughtMarriage, icon: "heart.fill")
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                
                                if let mbti = user.mbti {
                                    VStack(alignment: .leading, spacing: 15) {
                                        customSectionHeader(title: "パーソナリティ (MBTI)", icon: "sparkles")
                                        
                                        HStack(spacing: 20) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 22)
                                                    .fill(mbtiColor(mbti: mbti))
                                                    .frame(width: 100, height: 100)
                                                    .shadow(color: mbtiColor(mbti: mbti).opacity(0.3), radius: 8, x: 0, y: 4)
                                                
                                                WebImage(url: mbtiThumbnailURL) { view in
                                                    view
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 75, height: 75)
                                                } placeholder: {
                                                    ProgressView()
                                                        .tint(.white)
                                                }
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(mbti.uppercased())
                                                    .font(.system(size: 24, weight: .bold))
                                                    .foregroundStyle(mbtiColor(mbti: mbti))
                                                
                                                Text("性格タイプ")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(.gray)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(18)
                                        .background(Color.secondaryBackgroundColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 28))
                                        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                            .padding(.bottom, 160)
                        }
                    }
                    Spacer()
                        .frame(height: 150)
                }
                .ignoresSafeArea(edges: .top)
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            Task {
                guard let mbti = self.voiceChatViewModel.selectedVoiceChatRoom?.profile.user.mbti else { return }
                self.mbtiThumbnailURL = await self.voiceChatViewModel.fetchMBTIThumbnailURL(mbti: mbti)
            }
        }
    }
    
    @ViewBuilder
    private func attributeGridItem(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.selectedColor)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.8))
            }
            
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black.opacity(0.75))
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
    
    private func mbtiColor(mbti: String) -> Color {
        if mbti.containsSubsequence(subString: "nt") {
            return Color.mbtiPurpleColor
        } else if mbti.containsSubsequence(subString: "nf") {
            return Color.mbtiGreenColor
        } else if mbti.containsSubsequence(subString: "sj") {
            return Color.mbtiBlueColor
        } else {
            return Color.mbtiYellowColor
        }
    }
}

fileprivate struct VoiceChatLocationView: View {
    @EnvironmentObject private var voiceChatViewModel: VoiceChatViewModel
    
    @State private var selectedPlace: GooglePlacesSearchPlaceWrapper? = nil
    
    var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: .zero) {
                if let room = voiceChatViewModel.selectedVoiceChatRoom {
                    let places = room.places
                    
                    if places.count == 1 {
                        ScrollView(.vertical) {
                            VoiceChatLocationDetailView(wrapper: places.first!)
                                .environmentObject(voiceChatViewModel)
                            Spacer().frame(height: 150)
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            // Carousel for multiple locations
                            ScrollView(.horizontal) {
                                HStack(spacing: 16) {
                                    ForEach(places) { wrapper in
                                        locationCarouselItem(wrapper: wrapper)
                                            .onTapGesture {
                                                withAnimation(.spring()) {
                                                    self.selectedPlace = wrapper
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 120) // Space for header
                                .padding(.bottom, 20)
                            }
                            .scrollIndicators(.hidden)
                            
                            Divider()
                                .background(Color.black.opacity(0.05))
                                .padding(.horizontal, 24)
                            
                            // Detail view for the selected location
                            ScrollView(.vertical) {
                                if let selected = selectedPlace ?? places.first {
                                    VoiceChatLocationDetailView(wrapper: selected)
                                        .environmentObject(voiceChatViewModel)
                                        .id(selected.id)
                                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                                Spacer().frame(height: 150)
                            }
                            .scrollIndicators(.hidden)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
    
    @ViewBuilder
    private func locationCarouselItem(wrapper: GooglePlacesSearchPlaceWrapper) -> some View {
        let isSelected = (selectedPlace?.id ?? voiceChatViewModel.selectedVoiceChatRoom?.places.first?.id) == wrapper.id
        
        VStack(alignment: .leading, spacing: 8) {
            if let photo = wrapper.place?.photos?.first {
                WebImage(url: photo.buildUrl()) { view in
                    view.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().foregroundStyle(.gray.opacity(0.1)).skelton(isActive: true)
                }
                .frame(width: 120, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 120, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundStyle(.gray.opacity(0.3))
                    }
            }
            
            Text(wrapper.place?.displayName?.text ?? "No Name")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isSelected ? .black : .gray)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
        }
        .padding(8)
        .background(isSelected ? Color.mainColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.mainColor : Color.clear, lineWidth: 2)
        )
    }
}

fileprivate struct VoiceChatLocationDetailView: View {
    @EnvironmentObject private var voiceChatViewModel: VoiceChatViewModel
    let wrapper: GooglePlacesSearchPlaceWrapper
    
    @State private var scrollIdx: Int? = 0
    @State private var linkMetaData: LPLinkMetadata? = nil
    
    private let days: [String] = ["日", "月", "火", "水", "木", "金", "土"]
    private let daysColor: [Color] = [.blue, .black, .black, .black, .black, .black, .red]
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            VStack(alignment: .leading, spacing: .zero) {
                let photos = wrapper.place?.photos ?? []
                
                // MARK: - Photo Gallery
                ZStack(alignment: .bottom) {
                    ScrollView(.horizontal) {
                        HStack(alignment: .center, spacing: .zero) {
                            if photos.isEmpty {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .containerRelativeFrame(.horizontal)
                                    .frame(height: 520)
                                    .overlay {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 60))
                                            .foregroundStyle(.gray.opacity(0.3))
                                    }
                            } else {
                                ForEach(0..<min(5, photos.count), id: \.self) { idx in
                                    let photo = photos[idx]
                                    WebImage(url: photo.buildUrl()) { view in
                                        view
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Rectangle()
                                            .foregroundStyle(.gray.opacity(0.1))
                                            .skelton(isActive: true)
                                    }
                                    .containerRelativeFrame(.horizontal)
                                    .frame(height: 520)
                                    .clipped()
                                    .id(idx)
                                }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollPosition(id: $scrollIdx)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.paging)
                    
                    if photos.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(0..<min(5, photos.count), id: \.self) { idx in
                                Capsule()
                                    .frame(width: idx == scrollIdx ? 20 : 6, height: 6)
                                    .foregroundStyle(idx == scrollIdx ? .white : .white.opacity(0.4))
                                    .animation(.spring(response: 0.3), value: scrollIdx)
                            }
                        }
                        .padding(.bottom, 25)
                    }
                }
                .ignoresSafeArea(edges: .top)
                
                VStack(alignment: .leading, spacing: 32) {
                    // MARK: - Place Name & Address
                    VStack(alignment: .leading, spacing: 12) {
                        Text(wrapper.place?.displayName?.text ?? "不明なスポット")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.black.opacity(0.85))
                        
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.selectedColor)
                            
                            Text(wrapper.place?.formattedAddress ?? "住所情報なし")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.gray)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 25)
                    
                    // MARK: - Nearest transports
                    if voiceChatViewModel.isLoadingNearestTransports || !voiceChatViewModel.nearestTransports.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            customSectionHeader(title: "最寄りの交通機関", icon: "train.side.front.car")
                                .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal) {
                                HStack(alignment: .center, spacing: 15) {
                                    if voiceChatViewModel.isLoadingNearestTransports {
                                        ForEach(0..<3, id: \.self) { _ in
                                            transportSkeltonCardView
                                        }
                                    } else {
                                        ForEach(voiceChatViewModel.nearestTransports) { transport in
                                            transportCardView(transport: transport)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                            .scrollIndicators(.hidden)
                        }
                    }
                    
                    // MARK: - Place map
                    if let location = wrapper.place?.location {
                        VStack(alignment: .leading, spacing: 15) {
                            customSectionHeader(title: "エリアマップ", icon: "map.fill")
                            
                            GMSDetailMapStaticViewRepresentable(
                                clLocation: .init(latitude: location.latitude ?? .zero, longitude: location.longitude ?? .zero),
                                zoom: 13.0
                            )
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .background {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.secondaryBackgroundColor)
                                    .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 8)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // MARK: - Rating and reviews
                    if let rating = wrapper.place?.rating, rating > 0 {
                        VStack(alignment: .leading, spacing: 15) {
                            customSectionHeader(title: "評価とレビュー", icon: "star.bubble.fill")
                                .padding(.horizontal, 24)
                            
                            HStack(alignment: .center, spacing: 12) {
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 44, weight: .bold))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    ratingStarsView(rating: rating, size: 16)
                                    if let count = wrapper.place?.userRatingCount {
                                        Text("\(count)件のレビュー")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            if let reviews = wrapper.place?.reviews, !reviews.isEmpty {
                                ScrollView(.horizontal) {
                                    HStack(alignment: .center, spacing: 15) {
                                        ForEach(reviews, id: \.self) { review in
                                            ReviewCardView(review: review)
                                                .frame(width: 300)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 10)
                                }
                                .scrollIndicators(.hidden)
                            }
                        }
                        .padding(.top, 35)
                    }
                    
                    // MARK: - Opening hours
                    if (wrapper.place?.currentOpeningHours != nil) {
                        VStack(alignment: .leading, spacing: 15) {
                            customSectionHeader(title: "営業時間", icon: "clock.fill")
                            
                            if let openingHours = wrapper.place?.currentOpeningHours,
                               let weekDays = openingHours.weekdayDescriptions {
                                VStack(spacing: 0) {
                                    ForEach(0..<weekDays.count, id: \.self) { idx in
                                        let (_, startTime, endTime) = self.weekDayMatch(weekDays[(idx - 1 + weekDays.count) % weekDays.count])
                                        HStack {
                                            Text(days[idx])
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(daysColor[idx])
                                                .frame(width: 30, alignment: .leading)
                                            
                                            Spacer()
                                            
                                            if let start = startTime, let end = endTime {
                                                Text("\(start) — \(end)")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(.black.opacity(0.7))
                                            } else if startTime != nil {
                                                Text(startTime!)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(.black.opacity(0.7))
                                            } else {
                                                Text("定休日")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(.gray.opacity(0.5))
                                            }
                                        }
                                        .padding(.vertical, 12)
                                        
                                        if idx < weekDays.count - 1 {
                                            Divider().background(Color.gray.opacity(0.1))
                                        }
                                    }
                                }
                                .padding(20)
                                .background(Color.secondaryBackgroundColor)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 35)
                    }
                    
                    // MARK: - Place link
                    if let webSiteUri = wrapper.place?.websiteUri,
                       let url = URL(string: webSiteUri) {
                        VStack(alignment: .leading, spacing: 15) {
                            customSectionHeader(title: "公式Webサイト", icon: "safari.fill")
                            
                            if let metadata = self.linkMetaData {
                                LPLinkThumbnail(metadata: metadata)
                                    .padding(10)
                                    .background(Color.secondaryBackgroundColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
                            } else {
                                Text(webSiteUri)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.selectedColor)
                                    .underline()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 35)
                        .onAppear {
                            self.fetchMetadata(url: url)
                        }
                    }
                    
                    Spacer().frame(height: 180)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .onAppear {
            Task {
                await voiceChatViewModel.updateNearestTransport(wrapper: wrapper)
            }
        }
    }
        
    @ViewBuilder
    private func scrollCircleIndicator(count: Int) -> some View {
        HStack {
            Spacer()
            HStack(alignment: .center, spacing: 10) {
                ForEach(0..<count, id: \.self) { idx in
                    let diffIdx = Double(abs((scrollIdx ?? 0) - idx))
                    let scale = max(0.0, 1.0 - (diffIdx / Double(count)))
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(idx == scrollIdx ? Color.selectedColor : .gray.opacity(0.4))
                        .scaleEffect(scale)
                        .animation(.smooth, value: scrollIdx)
                }
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private func transportCardView(transport: GooglePlacesTransport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                let (imageName, _) = self.placeTypeImage(placeTypes: transport.place.types ?? [])
                if !imageName.isEmpty {
                    Image(systemName: imageName == "Railway Car" ? "tram.fill" : (imageName == "Bus" ? "bus.fill" : "ship.fill"))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mainColor)
                }
                
                Text(transport.place.displayName?.text ?? "駅名なし")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .lineLimit(1)
            }
            
            HStack(spacing: 4) {
                Text("現在地から")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.gray)
                Text(distanceFormat(transport.l2Distance))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.selectedColor)
            }
        }
        .padding(15)
        .frame(width: 220, height: 100, alignment: .topLeading)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var transportSkeltonCardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Circle()
                .frame(width: 24, height: 24)
                .foregroundStyle(.gray.opacity(0.1))
                .skelton(isActive: true)
            
            Rectangle()
                .frame(height: 16)
                .foregroundStyle(.gray.opacity(0.1))
                .skelton(isActive: true)
            
            Rectangle()
                .frame(width: 100, height: 12)
                .foregroundStyle(.gray.opacity(0.1))
                .skelton(isActive: true)
        }
        .padding(15)
        .frame(width: 220, height: 100)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    
    private func distanceFormat(_ distance: Double) -> String {
        if distance >= 1000 {
            let normDis = round((distance / 1000.0) * 10.0) / 10.0
            return normDis.description + "km"
        }
        
        let normDis = round(distance * 10.0) / 10.0
        return normDis.description + "m"
    }
    
    private func placeTypeImage(placeTypes: [String]) -> (String, String) {
        guard let firstPlaceType = placeTypes.first else { return ("", "") }
        
        if firstPlaceType == "train_station" {
            return ("Railway Car", "電車")
        } else if firstPlaceType == "subway_station" {
            return ("Railway Car", "地下鉄")
        } else if firstPlaceType == "ferry_terminal" {
            return ("Passenger Ship", "船乗り場")
        } else if firstPlaceType == "bus_station" {
            return ("Bus", "バス乗り場")
        } else {
            return ("", "")
        }
    }
    
    private func fetchMetadata(url: URL) {
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { meta, error in
            if let error = error {
                print("Failed to fetch metadata. \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                self.linkMetaData = meta
            }
        }
    }
    
    private func weekDayMatch(_ day: String) -> (String?, String?, String?) {
        if let match = day.firstMatch(of: /(.+曜日): (.+)/) {
            // Split days of week and date time.
            let day = String(match.1)
            let businessHours = match.2
            
            // Get business hours.
            let timePattern = /\d{1,2}時\d{2}分/
            let times = businessHours.matches(of: timePattern).map({ String($0.output) })
            
            if times.count == 2 {
                let startTime = timeFormat(time: times[0])
                let endTime = timeFormat(time: times[1])
                return (day.first?.description, startTime, endTime)
            }
            
            if times.count == 1 {
                let time = timeFormat(time: times[0])
                return (day.first?.description, time, nil)
            }
            
            return (day.first?.description, nil, nil)
        }
        
        return (nil, nil, nil)
    }
    
    private func timeFormat(time: String) -> String {
        let digits = time.matches(of: /\d+/).map { String($0.output) }
        if digits.count == 2 {
            // "10", "00" -> "10:00"
            return "\(digits[0]):\(digits[1])"
        }
        return time
    }
    
    @ViewBuilder
    private func ratingTextView(rating: Double, textSize: CGFloat, starSize: CGFloat, mean: Bool) -> some View {
        // normalize rating into 0.0 ~ 5.0
        let integer = Int(rating)
        let fraction = Int(round(rating.truncatingRemainder(dividingBy: 1)))
        let nonStars = 5 - integer - fraction
        HStack {
            Text((mean ? "平均: " : "") + String(rating))
                .font(.system(size: textSize, weight: .medium))
            HStack(alignment: .center) {
                ForEach(0..<integer, id: \.self) { _ in
                    Image("Star")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: starSize, height: starSize)
                }
                ForEach(0..<fraction, id: \.self) { _ in
                    Image("HalfStar")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: starSize, height: starSize)
                }
                ForEach(0..<nonStars, id: \.self) { _ in
                    Image("NonStar")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: starSize, height: starSize)
                }
            }
        }
    }
}

//// MARK: - Location Review Card
//fileprivate struct ReviewCardView: View {
//    let review: GooglePlacesSearchResponseReview
//    
//    @State private var isPopover: Bool = false
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 15) {
//            HStack(alignment: .center, spacing: 12) {
//                WebImage(url: URL(string: review.authorAttribution?.photoUri ?? "")) { image in
//                    image.resizable().scaledToFill()
//                } placeholder: {
//                    Circle().fill(Color.gray.opacity(0.1))
//                }
//                .frame(width: 42, height: 42)
//                .clipShape(Circle())
//                
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(review.authorAttribution?.displayName ?? "匿名ユーザー")
//                        .font(.system(size: 14, weight: .bold))
//                        .foregroundStyle(.black.opacity(0.8))
//                    
//                    if let rating = review.rating {
//                        HStack(spacing: 2) {
//                            ForEach(0..<5) { index in
//                                Image(systemName: "star.fill")
//                                    .font(.system(size: 10))
//                                    .foregroundStyle(index < rating ? .orange : .gray.opacity(0.2))
//                            }
//                        }
//                    }
//                }
//                Spacer()
//            }
//            
//            Text(review.text?.text ?? "")
//                .font(.system(size: 13, weight: .medium))
//                .foregroundStyle(.black.opacity(0.7))
//                .lineLimit(4)
//                .multilineTextAlignment(.leading)
//                .lineSpacing(4)
//                .fixedSize(horizontal: false, vertical: true)
//        }
//        .padding(18)
//        .frame(height: 180, alignment: .topLeading)
//        .background(Color.secondaryBackgroundColor)
//        .clipShape(RoundedRectangle(cornerRadius: 22))
//        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
//        .onTapGesture {
//            withAnimation(.spring()) {
//                self.isPopover.toggle()
//            }
//        }
//        .popup(isPresented: $isPopover) {
//            VStack(alignment: .leading, spacing: 20) {
//                HStack(spacing: 15) {
//                    WebImage(url: URL(string: review.authorAttribution?.photoUri ?? "")) { image in
//                        image.resizable().scaledToFill()
//                    } placeholder: {
//                        Circle().fill(Color.gray.opacity(0.1))
//                    }
//                    .frame(width: 50, height: 50)
//                    .clipShape(Circle())
//                    
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text(review.authorAttribution?.displayName ?? "匿名ユーザー")
//                            .font(.system(size: 16, weight: .bold))
//                        
//                        if let rating = review.rating {
//                            HStack(spacing: 2) {
//                                ForEach(0..<5) { index in
//                                    Image(systemName: "star.fill")
//                                        .font(.system(size: 12))
//                                        .foregroundStyle(index < rating ? .orange : .gray.opacity(0.2))
//                                }
//                            }
//                        }
//                    }
//                }
//                
//                ScrollView {
//                    Text(review.text?.text ?? "")
//                        .font(.system(size: 15, weight: .medium))
//                        .foregroundStyle(.black.opacity(0.8))
//                        .lineSpacing(6)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                }
//            }
//            .padding(25)
//            .background(Color.backgroundColor)
//            .clipShape(RoundedRectangle(cornerRadius: 30))
//            .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
//            .padding(.horizontal, 24)
//        } customize: { item in
//            item
//                .type(.floater())
//                .animation(.spring())
//                .closeOnTap(true)
//                .closeOnTapOutside(true)
//                .position(.center)
//                .appearFrom(.centerScale)
//                .backgroundColor(Color.black.opacity(0.4))
//        }
//    }
//}
