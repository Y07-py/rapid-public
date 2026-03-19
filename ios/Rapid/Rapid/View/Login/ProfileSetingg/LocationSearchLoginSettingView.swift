//
//  LocationSearchSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/03/08.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct LocationSearchLoginSettingView: View {
    @EnvironmentObject private var settingRootViewModel: RootViewModel<ProfileLoginSettingRoot>
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    @StateObject private var locationViewModel = UserLocationViewModel.shared
    
    @State private var showLocationAlert: Bool = false
    @FocusState private var focus: Bool
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color.backgroundColor.ignoresSafeArea()
            
            // Background Glows
            ZStack {
                Circle()
                    .fill(Color.selectedColor.opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(x: -120, y: -150)
                
                Circle()
                    .fill(Color.mainColor.opacity(0.15))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 120, y: 120)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 32) {
                headerView()
                
                spotSelectionCard()
                
                Spacer()
                
                navigationButtons()
            }
            .padding(.horizontal, 24)
        }
        .task {
            // Request permission if not determined
            if locationViewModel.authorizationStatus == .notDetermined {
                showLocationAlert = true
            }
            
            if profileLoginSettingViewModel.nearbySpots.isEmpty {
                await profileLoginSettingViewModel.fetchNearbySpots()
            }
        }
        .alert("位置情報の利用について", isPresented: $showLocationAlert) {
            Button("許可する") {
                locationViewModel.requestPermission()
            }
            Button("後で", role: .cancel) { }
        } message: {
            Text("近くの人気スポットを表示するために、位置情報の利用を許可してください。許可しなくても、登録した地域からスポットを提案します。")
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: locationViewModel.location) { _, newLocation in
            if newLocation != nil {
                Task {
                    await profileLoginSettingViewModel.fetchNearbySpots()
                }
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.focus = false
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func headerView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recruitment")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.selectedColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.selectedColor.opacity(0.1))
                .clipShape(Capsule())
            
            Text("最初の募集を\n作成しましょう")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(Color.primary)
            
            Text("行きたい場所を選んでみてください。")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }
    
    @ViewBuilder
    private func spotSelectionCard() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if profileLoginSettingViewModel.selectedSpot == nil {
                nearbySpotsList()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                recruitmentPostCard()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(24)
        .frame(maxHeight: 480)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .baseShadow()
    }
    
    @ViewBuilder
    private func nearbySpotsList() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("近くの人気スポット")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            if profileLoginSettingViewModel.isLoadingSpots {
                loadingView()
            } else if profileLoginSettingViewModel.nearbySpots.isEmpty {
                emptySpotsView()
            } else {
                spotsScrollView()
            }
        }
    }
    
    @ViewBuilder
    private func loadingView() -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("近くのスポットを探しています...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private func emptySpotsView() -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("スポットが見つかりませんでした")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private func spotsScrollView() -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(profileLoginSettingViewModel.nearbySpots, id: \.id) { spot in
                    spotRow(spot)
                }
            }
            .padding(.bottom, 8)
        }
    }
    
    @ViewBuilder
    private func spotRow(_ spot: GooglePlacesSearchResponsePlace) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                profileLoginSettingViewModel.selectedSpot = .init(place: spot)
            }
        }) {
            HStack(spacing: 16) {
                spotRowImage(spot)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(spot.displayName?.text ?? "不明なスポット")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                        .lineLimit(1)
                    
                    Text(spot.formattedAddress ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray.opacity(0.8))
                        .lineLimit(1)
                }
                
                Spacer()
                
                if let rating = spot.rating {
                    spotRatingBadge(rating)
                }
            }
            .buttonStyle(.plain)
            .padding(12)
            .background(Color.white.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .baseShadow()
            .padding(.horizontal, 5)
        }
    }
    
    @ViewBuilder
    private func spotRowImage(_ spot: GooglePlacesSearchResponsePlace) -> some View {
        ZStack {
            if let photo = spot.photos?.first {
                WebImage(url: photo.buildUrl()) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.gray.opacity(0.8))
                        .skelton(isActive: true)
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.selectedColor.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: categoryIcon(for: spot.types ?? []))
                    .foregroundStyle(Color.selectedColor)
                    .font(.system(size: 24))
            }
        }
    }
    
    @ViewBuilder
    private func spotRatingBadge(_ rating: Double) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                Text(String(format: "%.1f", rating))
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.1))
            .clipShape(Capsule())
        }
    }
    
    @ViewBuilder
    private func recruitmentPostCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("選択したスポット")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("変更") {
                    withAnimation {
                        profileLoginSettingViewModel.selectedSpot = nil
                    }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.selectedColor)
            }
            
            if let spot = profileLoginSettingViewModel.selectedSpot?.place {
                selectedSpotDetailView(spot)
            }
            
            messageInputView()
        }
    }
    
    @ViewBuilder
    private func selectedSpotDetailView(_ spot: GooglePlacesSearchResponsePlace) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                spotImageLarge(spot)
                
                if let priceLevel = spot.priceLevel, priceLevel != .unspecified {
                    priceBadge(priceLevel)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.displayName?.text ?? "不明なスポット")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    if let rating = spot.rating {
                        detailedRatingView(rating, count: Int(spot.userRatingCount ?? .zero))
                    }
                    
                    categoryTagView(spot)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(Color.white.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func spotImageLarge(_ spot: GooglePlacesSearchResponsePlace) -> some View {
        if let photo = spot.photos?.first {
            WebImage(url: photo.buildUrl()) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
            } placeholder: {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.1))
                    .skelton(isActive: true)
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .clipped()
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.selectedColor.opacity(0.1))
                .frame(height: 140)
                .overlay {
                    Image(systemName: categoryIcon(for: spot.types ?? []))
                        .font(.system(size: 40))
                        .foregroundStyle(Color.selectedColor.opacity(0.5))
                }
        }
    }
    
    @ViewBuilder
    private func priceBadge(_ priceLevel: GooglePlacesSearchResponsePriceLevel) -> some View {
        Text(priceString(for: priceLevel))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.6))
            .clipShape(Capsule())
            .padding(10)
    }
    
    @ViewBuilder
    private func detailedRatingView(_ rating: Double, count: Int?) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text(String(format: "%.1f", rating))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.orange)
            
            if let count = count {
                Text("(\(count))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.gray)
            }
        }
    }
    
    @ViewBuilder
    private func categoryTagView(_ spot: GooglePlacesSearchResponsePlace) -> some View {
        if let type = spot.types?.first(where: { !$0.contains("point_of_interest") && !$0.contains("establishment") }) {
            Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
    
    @ViewBuilder
    private func messageInputView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ひとことメッセージ")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
            
            TextEditor(text: $profileLoginSettingViewModel.recruitmentMessage)
                .focused($focus)
                .font(.system(size: 15))
                .padding(12)
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.05), lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if profileLoginSettingViewModel.recruitmentMessage.isEmpty {
                        Text("例: カフェでゆっくり話しませんか？")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                            .padding(16)
                    }
                }
        }
    }
    
    @ViewBuilder
    private func navigationButtons() -> some View {
        HStack(spacing: 16) {
            backButton()
            finishButton()
        }
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private func backButton() -> some View {
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
    }
    
    @ViewBuilder
    private func finishButton() -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                settingRootViewModel.push(.complete)
                profileLoginSettingViewModel.progress += 1
            }
        }) {
            Text(profileLoginSettingViewModel.selectedSpot == nil ? "後で設定する" : "投稿して完了する")
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

    private func categoryIcon(for types: [String]) -> String {
        if types.contains("cafe") || types.contains("coffee_shop") {
            return "cup.and.saucer.fill"
        } else if types.contains("bar") {
            return "wineglass.fill"
        } else if types.contains("amusement_center") || types.contains("video_arcade") {
            return "gamecontroller.fill"
        } else if types.contains("dessert_shop") || types.contains("bakery") {
            return "birthday.cake.fill"
        } else if types.contains("park") {
            return "leaf.fill"
        } else {
            return "mappin.circle.fill"
        }
    }
}
