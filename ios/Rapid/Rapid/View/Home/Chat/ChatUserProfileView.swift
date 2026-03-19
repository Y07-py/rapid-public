//
//  ChatUserProfileView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/03/02.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct ChatUserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var chatViewModel: ChatViewModel
    
    let user: RapidUserWithProfile
    
    @State private var scrollIdx: Int? = 0
    @State private var mbtiThumbnailURL: URL? = nil
    
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
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: .zero) {
                    // MARK: - Image Paging
                    ZStack(alignment: .bottom) {
                        ScrollView(.horizontal) {
                            HStack(alignment: .center, spacing: .zero) {
                                ForEach(Array(user.profileImages.enumerated()), id: \.element.id) { idx, image in
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
                        
                        if user.profileImages.count > 1 {
                            HStack(spacing: 6) {
                                ForEach(0..<user.profileImages.count, id: \.self) { idx in
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
                        let rawUser = user.user
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .bottom, spacing: 10) {
                                Text(rawUser.userName ?? "No name")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.85))
                                
                                Text("\(rawUser.birthDate?.computeAge() ?? 0)歳")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.black.opacity(0.6))
                                    .padding(.bottom, 2)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.selectedColor)
                                
                                Text(rawUser.residence ?? "居住地未設定")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 25)
                        
                        // MARK: - Introduction card
                        if let introduction = rawUser.introduction {
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
                                if let height = rawUser.height {
                                    attributeGridItem(title: "身長", value: "\(height)cm", icon: "ruler")
                                }
                                if let bodyType = rawUser.bodyType {
                                    attributeGridItem(title: "体型", value: bodyType, icon: "figure.arms.open")
                                }
                                if let bloodType = rawUser.bloodType {
                                    attributeGridItem(title: "血液型", value: "\(bloodType)型", icon: "drop.fill")
                                }
                                if let profession = rawUser.profession {
                                    attributeGridItem(title: "職業", value: profession, icon: "briefcase.fill")
                                }
                                if let income = rawUser.income {
                                    attributeGridItem(title: "年収", value: income, icon: "yensign.circle.fill")
                                }
                                if let childStatus = rawUser.childStatus {
                                    attributeGridItem(title: "子ども", value: childStatus, icon: "person.2.fill")
                                }
                                if let holidayType = rawUser.holidayType {
                                    attributeGridItem(title: "休日", value: holidayType, icon: "calendar")
                                }
                                if let smokingFrequency = rawUser.smokingFrequency {
                                    attributeGridItem(title: "喫煙", value: smokingFrequency, icon: "smoke.fill")
                                }
                                if let drinkingFrequency = rawUser.drinkingFrequency {
                                    attributeGridItem(title: "お酒", value: drinkingFrequency, icon: "wineglass.fill")
                                }
                                if let thoughtMarriage = rawUser.thoughtMarriage {
                                    attributeGridItem(title: "結婚意思", value: thoughtMarriage, icon: "heart.fill")
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // MARK: - MBTI Card
                        if let mbti = rawUser.mbti {
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
                    .padding(.bottom, 60)
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // Fixed Close Button overlay
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                .background {
                    LinearGradient(
                        colors: [.black.opacity(0.5), .black.opacity(0.2), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
                Spacer()
            }
        }
        .onAppear {
            Task {
                guard let mbti = user.user.mbti else { return }
                self.mbtiThumbnailURL = await chatViewModel.fetchMBTIThumbnailURL(mbti: mbti)
            }
        }
        .navigationBarBackButtonHidden(true)
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
