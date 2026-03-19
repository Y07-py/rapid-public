//
//  LocationSelectView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/12/29.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI


struct LocationSelectView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    @State private var isShowSearchFieldView: Bool = false
    @State private var isShowConfirmView: Bool = false
    
    @Namespace private var namespace
    
    @Binding var recruitmentCover: Bool
    @Binding var detailCover: Bool
    @Binding var candidateCover: Bool
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            // Decorative background glows
            VStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -150, y: -100)
                Spacer()
                Circle()
                    .fill(Color.thirdColor.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: 150, y: 100)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .center, spacing: .zero) {
                VStack(alignment: .center, spacing: 20) {
                    searchHeader
                }
                .padding(.bottom, 15)
                .background(Color.backgroundColor.opacity(0.8))
                .background(.ultraThinMaterial)
                .zIndex(1)
                
                LocationListView(
                    recruitmentCover: $recruitmentCover,
                    detailCover: $detailCover,
                    candidateCover: $candidateCover,
                    isShowConfirmView: $isShowConfirmView
                )
                .environmentObject(locationSelectViewModel)
                .blur(radius: isAuthorized ? 0 : 20)
                .disabled(!isAuthorized)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            
            if !isAuthorized {
                permissionRequiredOverlay
            }
            
            if locationSelectViewModel.isLoading && isAuthorized {
                LoadingOverlayView()
            }
        }
        .onAppear {
            if locationSelectViewModel.authorizationStatus == .notDetermined {
                locationSelectViewModel.requestLocationPermission()
            }
        }
        .fullScreenCover(isPresented: $isShowSearchFieldView) {
            LocationSearchRootView(isShowFieldView: $isShowSearchFieldView)
                .environmentObject(locationSelectViewModel)
        }
        .fullScreenCover(isPresented: $isShowConfirmView) {
            RecruitmentConfirmView(isShowScreen: $isShowConfirmView)
                .environmentObject(locationSelectViewModel)
        }
    }
    
    private var isAuthorized: Bool {
        let status = locationSelectViewModel.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
    
    @ViewBuilder
    private var permissionRequiredOverlay: some View {
        ZStack {
            Color.backgroundColor.opacity(0.6)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                ZStack {
                    Circle()
                        .fill(Color.mainColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "location.slash.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Color.mainColor)
                }
                
                VStack(spacing: 12) {
                    Text("位置情報が必要です")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                    
                    Text("この機能を利用するには、付近のスポットを取得するために位置情報の利用許可が必要です。設定から許可をお願いします。")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineSpacing(6)
                }
                
                Button(action: {
                    if locationSelectViewModel.authorizationStatus == .notDetermined {
                        locationSelectViewModel.requestLocationPermission()
                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text(locationSelectViewModel.authorizationStatus == .notDetermined ? "許可を求める" : "設定を開く")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .frame(height: 56)
                        .background(Color.mainColor)
                        .clipShape(Capsule())
                        .shadow(color: .mainColor.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(30)
        }
    }
    
    @ViewBuilder
    private var searchHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.3))
                
                Text("場所を検索する...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black.opacity(0.2))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.white.opacity(0.6))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            }
            .onTapGesture {
                isShowSearchFieldView.toggle()
            }
            
            Button(action: {
                
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowSearchFieldView.toggle()
                }
            }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        LinearGradient(
                            colors: [Color.mainColor, Color.mainColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.mainColor.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
    }
    
}

fileprivate struct LocationListView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    @Binding var recruitmentCover: Bool
    @Binding var detailCover: Bool
    @Binding var candidateCover: Bool
    @Binding var isShowConfirmView: Bool
    
    @State private var isShowNoSelectionAlert: Bool = false
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            VStack(alignment: .leading, spacing: .zero) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 40) {
                        // Famous locations
                        locationSection(
                            title: "人気のロケーション",
                            icon: "Star 1",
                            places: locationSelectViewModel.famousPlaces
                        )
                        
                        // Romantic locations
                        locationSection(
                            title: "ロマンチックなロケーション",
                            icon: "Wine Glass",
                            places: locationSelectViewModel.romanticPlaces
                        )
                        
                        // Relaxed locations
                        locationSection(
                            title: "落ち着いたロケーション",
                            icon: "Four Leaf Clover",
                            places: locationSelectViewModel.relaxedPlaces
                        )
                        
                        // Lively locations
                        locationSection(
                            title: "賑やかなロケーション",
                            icon: "Party Popper",
                            places: locationSelectViewModel.livelyPlaces
                        )
                        
                        // Natural locations
                        locationSection(
                            title: "自然を感じられるロケーション",
                            icon: "Evergreen Tree",
                            places: locationSelectViewModel.naturalPlaces
                        )
                        
                        Spacer().frame(height: 120)
                    }
                    .padding(.top, 25)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            floatingActionButtons
        }
        .alert("スポット未選択", isPresented: $isShowNoSelectionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("募集を作成するには、スポットを1箇所以上選択してください。")
        }
    }
    
    @ViewBuilder
    private func locationSection(title: String, icon: String, places: [GooglePlacesSearchPlaceWrapper]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.selectedColor.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
                
                Text(title)
                    .font(.system(size: 20, weight: .black))
                    .kerning(-0.5)
                    .foregroundStyle(Color.subFontColor.opacity(0.9))
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal) {
                HStack(alignment: .center, spacing: 20) {
                    ForEach(places) { wrapper in
                        LocationCardView(wrapper: wrapper, detailCover: $detailCover)
                            .environmentObject(locationSelectViewModel)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 15)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    @ViewBuilder
    private var floatingActionButtons: some View {
        Group {
            if locationSelectViewModel.activeRecruitment != nil {
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.isShowConfirmView.toggle()
                    }
                }) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                        
                        Text("投稿の確認")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 40)
                    .frame(height: 56)
                    .background(Color.mainColor)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
            } else {
                HStack(alignment: .center, spacing: 20) {
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.candidateCover.toggle()
                        }
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Image(systemName: "archivebox.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                
                                let selectedCount = locationSelectViewModel.selectedCandidates.count
                                if selectedCount > 0 {
                                    Text("\(selectedCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 18, height: 18)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 12, y: -12)
                                }
                            }
                            
                            Text("ボックス")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)
                        .frame(height: 56)
                        .background(Color.subFontColor)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: {
                        if locationSelectViewModel.selectedCandidates.isEmpty {
                            isShowNoSelectionAlert = true
                        } else {
                            locationSelectViewModel.prepareRecruitmentFromBox()
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                self.recruitmentCover.toggle()
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                            
                            Text("投稿")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)
                        .frame(height: 56)
                        .background(Color.mainColor)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}

fileprivate struct LocationCardView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    let wrapper: GooglePlacesSearchPlaceWrapper
    @Binding var detailCover: Bool
    
    private var isSelected: Bool {
        guard let id = wrapper.place?.id else { return false }
        return locationSelectViewModel.selectedCandidates.contains(where: { $0.place?.id == id })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Section with Overlays
            ZStack(alignment: .bottomLeading) {
                if let place = wrapper.place, let photo = place.photos?.first {
                    WebImage(url: photo.buildUrl()) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.1))
                            .skelton(isActive: true)
                    }
                    .frame(width: 260, height: 260)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 260, height: 260)
                        .overlay {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.subFontColor.opacity(0.1))
                        }
                }
                
                // Content Overlay (Gradient + Glassmorphism Panel)
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(wrapper.place?.displayName?.text ?? "Loading...")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Text(wrapper.place?.formattedAddress ?? "")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                // Badges
                HStack {
                    // Rating Badge (Glassmorphism)
                    if let rating = wrapper.place?.rating, rating > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Selection Badge
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.mainColor)
                            .background(Color.white.clipShape(Circle()))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(12)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: 260)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: isSelected ? Color.mainColor.opacity(0.2) : Color.black.opacity(0.08), radius: isSelected ? 15 : 12, x: 0, y: 8)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.mainColor.opacity(0.6), lineWidth: 3)
            }
        }
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .onTapGesture {
            self.locationSelectViewModel.selectedPlace = wrapper
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.detailCover.toggle()
            }
        }
    }
}

// MARK: - LocationHistory
fileprivate struct LocationsHistoryListView: View {
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.mainColor.opacity(0.2))
                
                Text("履歴はありません")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.6))
                
                Text("検索した場所や訪れた場所が\nここに表示されます")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 100)
        }
    }
}
