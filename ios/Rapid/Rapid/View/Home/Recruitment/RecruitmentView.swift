//
//  RecruitmentView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/21.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import Lottie
import PopupView

fileprivate enum RecruitmentTabType: Hashable {
    case list
    case chat
}

struct RecruitmentView: View {
    @EnvironmentObject private var recruitmentViewModel: RecruitmentViewModel
    @EnvironmentObject private var recruitmentRootViewModel: RootViewModel<RecruitmentRoot>
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @State private var showSearchFilterWindow: Bool = false
    @Namespace private var namespace
    
    @State private var liked: Bool = false
    @State private var likeAnimation: Bool = false
    @State private var isShowFilterWindow: Bool = false
    @State private var dummyChatTabIndex: ChatTabIndex = .chatList
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            // Decorative background glows
            VStack {
                Circle()
                    .fill(Color.selectedColor.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -150, y: -50)
                Spacer()
                Circle()
                    .fill(Color.mainColor.opacity(0.2))
                    .frame(width: 280, height: 280)
                    .blur(radius: 70)
                    .offset(x: 160, y: 50)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 10) {
                headerView
                
                RecruitCardListView(liked: $liked)
                    .environmentObject(recruitmentViewModel)
                    .environmentObject(homeRootViewModel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .popup(isPresented: $liked) {
            goodThumbsupView
        } customize: { item in
            item
                .type(.floater())
                .animation(.spring())
                .closeOnTap(true)
                .closeOnTapOutside(true)
                .autohideIn(1.5)
                .appearFrom(.centerScale)
                .position(.center)
        }
        .sheet(isPresented: $isShowFilterWindow) {
            RecruitmentFilterView(isShowWindow: $isShowFilterWindow)
                .environmentObject(recruitmentViewModel)
                .presentationDetents([.large])
        }
        .overlay {
            if recruitmentViewModel.isLoading {
                LoadingOverlayView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .fullScreenCover(isPresented: $recruitmentViewModel.isMatched) {
            MatchWindowView(
                isShowMatchWindow: $recruitmentViewModel.isMatched,
                selectedTabIndex: $dummyChatTabIndex,
                targetUser: recruitmentViewModel.selectedRecruitment?.profile
            )
            .environmentObject(chatViewModel)
            .environmentObject(profileViewModel)
            .environmentObject(homeRootViewModel)
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
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("さがす")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text("気になる相手を見つけましょう")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowFilterWindow.toggle()
                }
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(Color.secondaryBackgroundColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 70)
        .padding(.bottom, 5)
    }
}

fileprivate struct RecruitCardListView: View {
    @EnvironmentObject private var recruitmentViewModel: RecruitmentViewModel
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    
    @Binding var liked: Bool
    
    @State private var scrollPositionIdx: Int? = .zero
    
    var body: some View {
        if recruitmentViewModel.recruitments.isEmpty && !recruitmentViewModel.isLoading {
            emptyStateView
        } else {
            ScrollView(.vertical) {
                LazyVStack(spacing: 25) {
                    let count = recruitmentViewModel.recruitments.count
                    ForEach(0..<count, id: \.self) { idx in
                        let recruitment = recruitmentViewModel.recruitments[idx]
                        Button(action: {
                            recruitmentViewModel.selectedRecruitment = recruitment
                            homeRootViewModel.push(.recruitment)
                        }) {
                            VStack(alignment: .leading, spacing: 0) {
                                ProfileCardListView(
                                    profile: recruitment.profile,
                                    message: recruitment.recruitment.recruitmentWithRelations.message
                                )
                                .environmentObject(recruitmentViewModel)
                                
                                placeCardView(recruitment: recruitment)
                            }
                            .background(Color.secondaryBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                            .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 8)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                        .id(idx)
                    }
                }
                .padding(.top, 15)
                .padding(.bottom, 40)
                .scrollTargetLayout()
                Spacer()
                    .frame(height: 100)
            }
            .scrollIndicators(.hidden)
            .scrollPosition(id: $scrollPositionIdx)
            .onChange(of: scrollPositionIdx) { _, newValue in
                if let newValue = newValue, newValue + 1 == self.recruitmentViewModel.recruitments.count {
                    self.recruitmentViewModel.updateRecruitmentsOffset()
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.selectedColor.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "person.2.slash.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Color.selectedColor.opacity(0.6))
            }
            
            VStack(spacing: 12) {
                Text("現在、募集はありません")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text("条件を変更して検索するか、\nしばらく時間をおいてから再度お試しください。")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.bottom, 100)
    }
    
    @ViewBuilder
    private func placeCardView(recruitment: RecruitmentWithUserProfile) -> some View {
        let places = recruitment.places
        VStack(alignment: .leading, spacing: 18) {
            // Location Header
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.selectedColor)
                
                Text(places.isEmpty ? "ロケーション未設定" : "ロケーション")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black.opacity(0.7))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            if !places.isEmpty {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(places) { place in
                            VStack(alignment: .leading, spacing: 10) {
                                // Place Image with Price/Type overlay
                                ZStack(alignment: .bottomLeading) {
                                    if let photo = place.place?.photos?.first {
                                        WebImage(url: photo.buildUrl()) { view in
                                            view
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            Rectangle()
                                                .foregroundStyle(.gray.opacity(0.1))
                                                .skelton(isActive: true)
                                        }
                                        .frame(width: 240, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                    } else {
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(width: 240, height: 140)
                                            .overlay {
                                                Image(systemName: "photo")
                                                    .foregroundStyle(.gray.opacity(0.3))
                                            }
                                    }
                                    
                                    // Price Level Overlay
                                    if let priceLevel = place.place?.priceLevel, priceLevel != .unspecified {
                                        Text(priceString(for: priceLevel))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.black.opacity(0.6))
                                            .clipShape(Capsule())
                                            .padding(10)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(place.place?.displayName?.text ?? "不明なスポット")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.black.opacity(0.8))
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 12) {
                                        // Rating
                                        if let rating = place.place?.rating {
                                            HStack(spacing: 3) {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.orange)
                                                Text(String(format: "%.1f", rating))
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(.orange)
                                                
                                                if let count = place.place?.userRatingCount {
                                                    Text("(\(count))")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundStyle(.gray)
                                                }
                                            }
                                        }
                                        
                                        // Type tag
                                        if let type = place.place?.types?.first(where: { !$0.contains("point_of_interest") && !$0.contains("establishment") }) {
                                            Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(.gray)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.gray.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                            .frame(width: 240)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 5)
                }
                .scrollIndicators(.hidden)
            }
            
            // Like Action Button
            HStack(alignment: .center) {
                Button(action: {
                    if recruitment.recruitment.like == nil {
                        recruitmentViewModel.selectedRecruitment = recruitment
                        recruitmentViewModel.sendLike()
                        withAnimation {
                            self.liked.toggle()
                        }
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: recruitment.recruitment.like != nil || liked ? "checkmark.seal.fill" : "hand.thumbsup.fill")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text(recruitment.recruitment.like != nil || liked ? "いいね済み" : "いいね")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        recruitment.recruitment.like != nil ? 
                        Color.likedColor : 
                        Color.mainColor
                    )
                    .clipShape(Capsule())
                    .shadow(color: (recruitment.recruitment.like != nil ? Color.likedColor : Color.mainColor).opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(recruitment.recruitment.like != nil)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .padding(.top, 10)
    }
    
    private func priceString(for level: GooglePlacesSearchResponsePriceLevel) -> String {
        switch level {
        case .free: return "Free"
        case .inexpensive: return "$"
        case .moderate: return "$$"
        case .expensive: return "$$$"
        case .veryExpensive: return "$$$$"
        default: return ""
        }
    }
}

fileprivate struct ProfileCardListView: View {
    @EnvironmentObject private var recruitmentViewModel: RecruitmentViewModel
    
    let profile: RapidUserWithProfile
    let message: String?
    
    @State private var scrollIdx: Int? = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                ScrollView(.horizontal) {
                    HStack(alignment: .center, spacing: .zero) {
                        if profile.profileImages.isEmpty {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .containerRelativeFrame(.horizontal)
                                .frame(height: 480)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 80))
                                        .foregroundStyle(.gray.opacity(0.3))
                                }
                        } else {
                            ForEach(0..<profile.profileImages.count, id: \.self) { idx in
                                let image = profile.profileImages[idx]
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
                                .frame(height: 480)
                                .clipped()
                                .id(idx)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $scrollIdx)
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                
                // Info Overlay
                VStack(alignment: .leading, spacing: 10) {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(profile.user.userName ?? "No name")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.white)
                                
                                Text("\(profile.user.birthDate?.computeAge() ?? 0)歳")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                            
                            if let residence = profile.user.residence {
                                Label(residence, systemImage: "mappin.and.ellipse")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.black.opacity(0.3))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Spacer()
                        
                        // Page Indicator
                        if profile.profileImages.count > 1 {
                            HStack(spacing: 6) {
                                ForEach(0..<profile.profileImages.count, id: \.self) { idx in
                                    Circle()
                                        .frame(width: 7, height: 7)
                                        .foregroundStyle(idx == scrollIdx ? .white : .white.opacity(0.4))
                                        .scaleEffect(idx == scrollIdx ? 1.2 : 1.0)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .background {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
            
            // Message Box
            if let message = message, !message.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.selectedColor)
                        
                        Text(message)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black.opacity(0.75))
                            .lineSpacing(6)
                        
                        Spacer()
                    }
                    .padding(20)
                    .background(Color.selectedColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.selectedColor.opacity(0.1), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 15)
            } else {
                 Spacer().frame(height: 15)
            }
        }
    }
}
