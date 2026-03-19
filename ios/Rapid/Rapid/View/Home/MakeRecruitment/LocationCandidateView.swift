//
//  LocationCandidateView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/02.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

fileprivate enum SelectedTabType: Hashable {
    case selectedList
    case selectedHistory
}

struct LocationCandidateView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    @Binding var candidateCover: Bool
    
    @State private var selectedTabIndex: Int = 0
    @State private var selectedTabType: SelectedTabType = .selectedList
    @Namespace private var namespace
    
    
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
                headerView
                
                TabView(selection: $selectedTabIndex) {
                    LocationCandidateListView()
                        .environmentObject(locationSelectViewModel)
                        .tag(0)
                    
                    LocationCandidateHistoryListView()
                        .environmentObject(locationSelectViewModel)
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onChange(of: selectedTabIndex) { _, newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.selectedTabType = (newValue == 0 ? .selectedList : .selectedHistory)
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 20) {
            // Modal Handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 10)
            
            HStack(alignment: .center) {
                Text("ボックス")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        candidateCover = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.gray.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            
            HStack(spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTabIndex = 0
                    }
                }) {
                    Text("選択中")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(selectedTabType == .selectedList ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if selectedTabType == .selectedList {
                                Capsule()
                                    .fill(Color.mainColor)
                                    .matchedGeometryEffect(id: "tab", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTabIndex = 1
                    }
                }) {
                    Text("選択履歴")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(selectedTabType == .selectedHistory ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if selectedTabType == .selectedHistory {
                                Capsule()
                                    .fill(Color.mainColor)
                                    .matchedGeometryEffect(id: "tab", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(4)
            .background(Color.white.opacity(0.5))
            .clipShape(Capsule())
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 15)
        .background(Color.backgroundColor.opacity(0.8))
        .background(.ultraThinMaterial)
        .zIndex(1)
    }
}

fileprivate struct LocationCandidateListView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    @State private var isShowScreen: Bool = false
    @State private var isAlert: Bool = false
    
    var body: some View {
        ZStack {
            if locationSelectViewModel.selectedCandidates.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.mainColor.opacity(0.2))
                    
                    Text("スポットが選択されていません")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black.opacity(0.6))
                    
                    Text("募集に追加したいスポットを\n検索して選択してください")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.bottom, 100)
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .center, spacing: 16) {
                        ForEach(locationSelectViewModel.selectedCandidates) { candidate in
                            candidateCardView(candidate: candidate)
                        }
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .fullScreenCover(isPresented: $isShowScreen) {
            LocationDetailView(isShowScreen: $isShowScreen, viewMode: .candidate)
                .environmentObject(locationSelectViewModel)
        }
    }
    
    @ViewBuilder
    private func candidateCardView(candidate: GooglePlacesSearchPlaceWrapper) -> some View {
        if let place = candidate.place {
            HStack(spacing: 16) {
                // Image with fallback
                if let photo = place.photos?.first {
                    WebImage(url: photo.buildUrl()) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().foregroundStyle(.gray.opacity(0.1)).skelton(isActive: true)
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundStyle(.gray.opacity(0.3))
                        }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.displayName?.text ?? "No Name")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                        .lineLimit(1)
                    
                    Text(place.formattedAddress ?? "")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                    
                    if let rating = place.rating {
                        ratingStarsView(rating: rating)
                    }
                }
                
                Spacer()
                
                // Trash Button
                Button(action: {
                    self.locationSelectViewModel.selectedPlace = candidate
                    self.isAlert = true
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.red.opacity(0.6))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 20)
            .onTapGesture {
                locationSelectViewModel.selectedPlace = candidate
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowScreen.toggle()
                }
            }
            .alert("候補の削除", isPresented: $isAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("削除", role: .destructive) {
                    withAnimation {
                        self.locationSelectViewModel.removePlace()
                    }
                }
            } message: {
                Text("このスポットをリストから削除しますか？")
            }
        }
    }
    
    @ViewBuilder
    private func ratingStarsView(rating: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Image(systemName: index < Int(rating) ? "star.fill" : (index < Int(rating.rounded()) ? "star.leadinghalf.filled" : "star"))
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
            
            Text(String(format: "%.1f", rating))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.gray)
                .padding(.leading, 4)
        }
    }
}

fileprivate struct LocationCandidateHistoryListView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.mainColor.opacity(0.2))
                
                Text("履歴はありません")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.6))
                
                Text("過去に選択したスポットが\nここに表示されます")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 100)
        }
    }
}
