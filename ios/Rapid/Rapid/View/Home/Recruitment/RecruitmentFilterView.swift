//
//  RecruitmentFilterView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/25.
//

import Foundation
import SwiftUI

struct RecruitmentFilterView: View {
    @EnvironmentObject private var recruitmentViewModel: RecruitmentViewModel
    
    @Binding var isShowWindow: Bool
    
    // State variables for the filters
    @State private var minAge: Double = 18
    @State private var maxAge: Double = 50
    @State private var useRadiusFilter: Bool = false
    @State private var searchRadius: Double = 5 // Radius in km
    @State private var locationKeyword: String = ""
    @State private var sortByLastLogin: Bool = true // Default to true based on previous sortLogin: Bool logic
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            // Subtle decorative background glows
            VStack {
                Circle()
                    .fill(Color.selectedColor.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: -120, y: -50)
                Spacer()
                Circle()
                    .fill(Color.mainColor.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .blur(radius: 50)
                    .offset(x: 120, y: 50)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: .zero) {
                headerView
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        // 1. Age Filter
                        ageSection
                        
                        // 2. Residence Filter (Radius)
                        residenceRadiusSection
                        
                        // 3. Location Filter (Text)
                        locationSection
                        
                        // 4. Last Login Filter
                        lastLoginSection
                        
                        applyButton
                        
                        Spacer().frame(height: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                }
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("検索条件")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text("あなたにぴったりの相手を探しましょう")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowWindow.toggle()
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.gray.opacity(0.2))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 25)
        .padding(.bottom, 15)
    }
    
    @ViewBuilder
    private var ageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(title: "年齢範囲", icon: "person.2.fill", color: Color.selectedColor)
            
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("年齢")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                    Spacer()
                    Text("\(Int(minAge))歳 〜 \(Int(maxAge))歳")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.selectedColor)
                }
                
                VStack(spacing: 8) {
                    // Min Age Multi-Slider implementation (Using two sliders for simplicity, but themed)
                    VStack(spacing: 0) {
                        Slider(value: $minAge, in: 18...80, step: 1)
                            .tint(Color.selectedColor)
                            .onChange(of: minAge) { _, newValue in
                                if newValue > maxAge {
                                    minAge = maxAge
                                }
                            }
                        
                        Slider(value: $maxAge, in: 18...80, step: 1)
                            .tint(Color.selectedColor)
                            .onChange(of: maxAge) { _, newValue in
                                if newValue < minAge {
                                    maxAge = minAge
                                }
                            }
                    }
                }
            }
            .padding(20)
            .background(Color.secondaryBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
        }
    }
    
    @ViewBuilder
    private var residenceRadiusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(title: "現在地からの距離", icon: "location.fill", color: Color.mainColor)
            
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("距離で絞り込む")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                    Spacer()
                    Toggle("", isOn: $useRadiusFilter)
                        .tint(Color.mainColor)
                }
                
                if useRadiusFilter {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("検索半径")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.gray)
                            Spacer()
                            Text("\(Int(searchRadius))km 以内")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.mainColor)
                        }
                        
                        Slider(value: $searchRadius, in: 1...30, step: 1)
                            .tint(Color.mainColor)
                        
                        HStack {
                            Text("1km")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.gray.opacity(0.5))
                            Spacer()
                            Text("30km")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                    }
                    .padding(.top, 5)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(20)
            .background(Color.secondaryBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
        }
    }
    
    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(title: "ロケーション検索", icon: "mappin.and.ellipse", color: Color.selectedColor)
            
            HStack(spacing: 15) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.selectedColor)
                    .font(.system(size: 18, weight: .bold))
                
                TextField("場所やキーワードで検索", text: $locationKeyword)
                    .font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color.secondaryBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
        }
    }
    
    @ViewBuilder
    private var lastLoginSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(title: "並び替え設定", icon: "arrow.up.arrow.down.circle.fill", color: Color.mainColor)
            
            HStack {
                Text("最終ログインが新しい順")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.7))
                
                Spacer()
                
                Toggle("", isOn: $sortByLastLogin)
                    .tint(Color.mainColor)
            }
            .padding(20)
            .background(Color.secondaryBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
        }
    }
    
    @ViewBuilder
    private var applyButton: some View {
        Button(action: {
            withAnimation(.spring()) {
                self.isShowWindow.toggle()
                self.recruitmentViewModel.fetchRecruitmentWithFilter()
            }
        }) {
            Text("この条件で検索する")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.mainColor)
                .clipShape(Capsule())
                .shadow(color: Color.mainColor.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .padding(.top, 20)
    }
    
    private func sectionTitle(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.gray)
                .kerning(0.5)
        }
        .padding(.leading, 5)
    }
}
