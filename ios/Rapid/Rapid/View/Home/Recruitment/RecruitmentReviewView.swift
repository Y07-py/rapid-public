//
//  RecruitmentReviewView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/29.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import PopupView
import LinkPresentation
import CoreLocation
import Lottie

fileprivate enum ReviewWindowType: Hashable {
    case profile
    case location
}

struct RecruitmentReviewView: View {
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    @EnvironmentObject private var recruitmentViewModel: RecruitmentViewModel
    
    @State private var selectedTabIdx: Int = 0
    @State private var reviewWindowType: ReviewWindowType = .profile
    @State private var liked: Bool = false
    @State private var likeAnimation: Bool = false
    
    @Namespace private var namespace
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            // Decorative background glows
            VStack {
                Circle()
                    .fill(Color.selectedColor.opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(x: -160, y: -80)
                Spacer()
                Circle()
                    .fill(Color.mainColor.opacity(0.15))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 160, y: 80)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .center, spacing: .zero) {
                switch reviewWindowType {
                case .profile:
                    RecruitmentUserProfileView()
                        .environmentObject(recruitmentViewModel)
                case .location:
                    RecruitmentLocationView()
                        .environmentObject(recruitmentViewModel)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .overlay(alignment: .top) {
                tabHeaderView
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            Button(action: {
                withAnimation {
                    self.liked.toggle()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.recruitmentViewModel.sendLike()
                    self.homeRootViewModel.pop(1)
                    self.liked.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: recruitmentViewModel.selectedRecruitment?.recruitment.like != nil ? "checkmark.seal.fill" : "hand.thumbsup.fill")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text(recruitmentViewModel.selectedRecruitment?.recruitment.like != nil ? "いいね済み" : "いいね")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    recruitmentViewModel.selectedRecruitment?.recruitment.like != nil ? 
                    Color.likedColor : 
                    Color.mainColor
                )
                .clipShape(Capsule())
                .shadow(color: (recruitmentViewModel.selectedRecruitment?.recruitment.like != nil ? Color.likedColor : Color.mainColor).opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 25)
            .disabled(recruitmentViewModel.selectedRecruitment?.recruitment.like != nil)
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
        .onAppear {
            if let recruitmentId = recruitmentViewModel.selectedRecruitment?.id {
                Task {
                    await recruitmentViewModel.fetchFullRecruitmentDetail(recruitmentId: recruitmentId)
                }
            }
        }
    }
    
    @ViewBuilder
    private var tabHeaderView: some View {
        HStack {
            Button(action: {
                homeRootViewModel.pop(1)
                withAnimation {
                    self.liked = false
                }
            }) {
                Circle()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.ultraThinMaterial)
                    .overlay {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            HStack(spacing: .zero) {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.reviewWindowType = .profile
                    }
                }) {
                    Text("プロフィール")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(reviewWindowType == .profile ? .white : .white.opacity(0.6))
                        .frame(width: 100, height: 38)
                        .background {
                            if reviewWindowType == .profile {
                                Capsule()
                                    .fill(Color.mainColor)
                                    .matchedGeometryEffect(id: "tab", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.reviewWindowType = .location
                    }
                }) {
                    Text("ロケーション")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(reviewWindowType == .location ? .white : .white.opacity(0.6))
                        .frame(width: 100, height: 38)
                        .background {
                            if reviewWindowType == .location {
                                Capsule()
                                    .fill(Color.mainColor)
                                    .matchedGeometryEffect(id: "tab", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            
            Spacer()
            
            // Empty placeholder for symmetry
            Circle()
                .frame(width: 44, height: 44)
                .foregroundStyle(.clear)
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

fileprivate struct RecruitmentUserProfileView: View {
    @EnvironmentObject private var recruitmentViewModel: RecruitmentViewModel
    
    @State private var scrollIdx: Int? = 0
    @State private var mbtiThumbnailURL: URL? = nil
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: .zero) {
                if let recruitment = recruitmentViewModel.selectedRecruitment {
                    // MARK: - Image Paging
                    ZStack(alignment: .bottom) {
                        ScrollView(.horizontal) {
                            HStack(alignment: .center, spacing: .zero) {
                                ForEach(Array(recruitment.profile.profileImages.enumerated()), id: \.element.id) { idx, image in
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
                        
                        if recruitment.profile.profileImages.count > 1 {
                            HStack(spacing: 6) {
                                ForEach(0..<recruitment.profile.profileImages.count, id: \.self) { idx in
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
                        let user = recruitment.profile.user
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
                        
                        // MARK: - Introduction card
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
                        
                        // MARK: - Profile Info Grid
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
                        
                        // MARK: - MBTI Card
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
                    .padding(.bottom, 160) // Space for Like button
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            Task {
                guard let mbti = recruitmentViewModel.selectedRecruitment?.profile.user.mbti else { return }
                self.mbtiThumbnailURL = await recruitmentViewModel.fetchMBTIThumbnailURL(mbti: mbti)
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
