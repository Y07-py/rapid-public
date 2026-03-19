//
//  LocationSearchFieldView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/13.
//

import Foundation
import SwiftUI

struct LocationSearchFieldView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @EnvironmentObject private var locationSearchRootViewModel: RootViewModel<LocationSearchRoot>
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @Binding var isShowFieldView: Bool
    @Binding var searchResults: [GooglePlacesSearchPlaceWrapper]
    @Binding var query: String
    
    // Category property
    @State private var isShowCategoryList: Bool = false
    
    // Search range property
    @State private var isShowSearchRangeList: Bool = false
    
    @State private var isShowPointPayWallAlert: Bool = false
    @State private var isShowPointPayWall: Bool = false
    
    @FocusState private var focus: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background blur/dim aligned with app tone
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        self.focus = false
                    }
                }
            
            VStack(spacing: 20) {
                headerView
                
                VStack(spacing: 24) {
                    // Main Search Card
                    VStack(alignment: .leading, spacing: 24) {
                        Text("スポットを探す")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.black.opacity(0.85))
                        
                        // Search Bar (Unified with original: Icon on the right, separate button)
                        HStack(spacing: 12) {
                            HStack(spacing: 12) {
                                TextField("店名やキーワードを入力", text: $query)
                                    .focused($focus)
                                    .font(.system(size: 16, weight: .medium))
                                    .submitLabel(.search)
                                    .onSubmit {
                                        locationSearch()
                                    }
                                
                                if !query.isEmpty {
                                    Button(action: { query = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.gray.opacity(0.5))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .background(Color.backgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                            )
                            
                            Button(action: locationSearch) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.mainColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
                            }
                        }
                        
                        // Filters (Category & Range)
                        VStack(spacing: 16) {
                            filterButton(
                                title: "カテゴリ",
                                subtitle: selectedCategoriesText,
                                icon: "tag.fill",
                                color: .orange
                            ) {
                                isShowCategoryList = true
                            }
                            .sheet(isPresented: $isShowCategoryList) {
                                SearchCategoryListView()
                                    .environmentObject(locationSelectViewModel)
                                    .presentationDetents([.medium, .large])
                                    .presentationDragIndicator(.visible)
                            }
                            
                            filterButton(
                                title: "検索範囲",
                                subtitle: searchRadiusFormat(radius: locationSelectViewModel.searchRadius),
                                icon: "mappin.and.ellipse",
                                color: .blue
                            ) {
                                isShowSearchRangeList = true
                            }
                            .sheet(isPresented: $isShowSearchRangeList) {
                                SearchRangeView()
                                    .environmentObject(locationSelectViewModel)
                                    .presentationDetents([.height(280)])
                                    .presentationDragIndicator(.visible)
                            }
                        }
                    }
                    .padding(24)
                    .background(Color.secondaryBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    
                    // History Card
                    if !locationSelectViewModel.searchQueries.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                             HStack {
                                Text("最近の検索")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.7))
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 8) {
                                    ForEach(locationSelectViewModel.searchQueries) { history in
                                        HStack(spacing: 12) {
                                            Image(systemName: "clock")
                                                .font(.system(size: 16))
                                                .foregroundStyle(.gray.opacity(0.8))
                                            
                                            Text(history.query)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.black.opacity(0.8))
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                withAnimation(.spring()) {
                                                    locationSelectViewModel.deleteSearchQuery(query: history)
                                                }
                                            }) {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(.gray.opacity(0.6))
                                                    .padding(8)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.backgroundColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .onTapGesture {
                                            query = history.query
                                            
                                            locationSearch()
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 180)
                        }
                        .padding(20)
                        .background(Color.secondaryBackgroundColor.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert("ポイントが不足しています", isPresented: $isShowPointPayWallAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("チャージする") {
                isShowPointPayWall = true
            }
        } message: {
            Text("検索を実行するにはポイントが不足しています。ポイントをチャージしますか？")
        }
        .fullScreenCover(isPresented: $isShowPointPayWall) {
            PointPurchasePayWallView(isPresented: $isShowPointPayWall)
                .environmentObject(profileViewModel)
        }
    }
    
    private var selectedCategoriesText: String {
        let selected = locationSelectViewModel.selectedLocationCategory
        if selected.isEmpty {
            return "指定なし"
        } else if selected.count == 1 {
            return selected[0].name
        } else {
            return "\(selected[0].name) + \(selected.count - 1)"
        }
    }
    
    @ViewBuilder
    private func filterButton(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.gray)
                    Text(subtitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.5))
            }
            .padding(12)
            .background(Color.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var headerView: some View {
        HStack {
            Spacer()
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isShowFieldView = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.gray)
                    .frame(width: 36, height: 36)
                    .background(Color.backgroundColor, in: Circle())
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func locationSearch() {
        if profileViewModel.totalPoint - 10 < 0 {
            isShowPointPayWallAlert = true
            return
        }
        
        self.locationSearchRootViewModel.push(.map)
        Task {
            self.searchResults = await self.locationSelectViewModel.locationSearch(query: query, offset: 0)
        }
    }
    
    private func searchRadiusFormat(radius: Double) -> String {
        if radius < 1000 {
            return String(format: "%.0fm以内", radius)
        } else {
            let km = radius / 1000
            return String(format: "%.1fkm以内", km)
        }
    }
}

fileprivate struct SearchCategoryListView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var categoryQuery: String = ""
    @State private var hitCategories: [LocationCategory] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)
                    TextField("カテゴリを検索 (例: カフェ, 公園)", text: $categoryQuery)
                }
                .padding()
                .background(Color.secondaryBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
                
                // Selected Preview
                if !locationSelectViewModel.selectedLocationCategory.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(locationSelectViewModel.selectedLocationCategory) { cat in
                                HStack(spacing: 4) {
                                    Text(cat.name)
                                    Button(action: {
                                        locationSelectViewModel.updateSelectedLocationCategories(category: cat)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.mainColor)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                
                List {
                    ForEach(hitCategories) { category in
                        Button(action: {
                            locationSelectViewModel.updateSelectedLocationCategories(category: category)
                        }) {
                            HStack {
                                Text(category.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.8))
                                Spacer()
                                if isSelected(category) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.mainColor)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("カテゴリ選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .onChange(of: categoryQuery) { _, newValue in
                hitCategories = locationSelectViewModel.searchCatgory(query: newValue)
            }
            .onAppear {
                hitCategories = locationSelectViewModel.locationCategories
            }
        }
    }
    
    private func isSelected(_ category: LocationCategory) -> Bool {
        locationSelectViewModel.selectedLocationCategory.contains(where: { $0.id == category.id })
    }
}

fileprivate struct SearchRangeView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text(searchRadiusFormat(radius: locationSelectViewModel.searchRadius))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color.mainColor)
                
                Text("検索する最大距離を指定します")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray)
            }
            .padding(.top, 20)
            
            Slider(value: $locationSelectViewModel.searchRadius, in: 500...50000, step: 500)
                .tint(Color.mainColor)
                .padding(.horizontal, 32)
            
            Button(action: { dismiss() }) {
                Text("設定する")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.mainColor)
                    .clipShape(Capsule())
                    .padding(.horizontal, 32)
            }
        }
        .padding(.bottom, 40)
    }
    
    private func searchRadiusFormat(radius: Double) -> String {
        if radius < 1000 {
            return String(format: "%.0fm", radius)
        } else {
            return String(format: "%.1fkm", radius / 1000)
        }
    }
}

