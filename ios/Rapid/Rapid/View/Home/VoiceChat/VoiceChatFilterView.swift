//
//  VoiceChatFilterView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/03/04.
//

import SwiftUI

struct VoiceChatFilterView: View {
    @EnvironmentObject private var voiceChatViewModel: VoiceChatViewModel
    @Binding var isShowWindow: Bool
    
    // State variables for the filters (Dummy values for UI)
    @State private var minAge: Double = 18
    @State private var maxAge: Double = 50
    @State private var selectedResidence: String = "未設定"
    @State private var useDistanceFilter: Bool = false
    @State private var searchRadius: Double = 10
    
    private var residences: [String] {
        voiceChatViewModel.uniquePrefectures
    }
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: .zero) {
                headerView
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        // 1. Age Filter
                        ageSection
                        
                        // 2. Residence Filter
                        residenceSection
                        
                        // 3. Distance Filter (Optional)
                        distanceSection
                        
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
                Text("フィルター")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text("表示する相手を絞り込みます")
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
            sectionTitle(title: "年齢範囲", icon: "person.2.fill", color: Color.thirdColor)
            
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("年齢")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                    Spacer()
                    Text("\(Int(minAge))歳 〜 \(Int(maxAge))歳")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.thirdColor)
                }
                
                VStack(spacing: 8) {
                    Slider(value: $minAge, in: 18...80, step: 1)
                        .tint(Color.thirdColor)
                        .onChange(of: minAge) { _, newValue in
                            if newValue > maxAge {
                                minAge = maxAge
                            }
                        }
                    
                    Slider(value: $maxAge, in: 18...80, step: 1)
                        .tint(Color.thirdColor)
                        .onChange(of: maxAge) { _, newValue in
                            if newValue < minAge {
                                maxAge = minAge
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
    private var residenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(title: "居住地", icon: "mappin.and.ellipse", color: Color.mainColor)
            
            Menu {
                Picker("Residence", selection: $selectedResidence) {
                    ForEach(residences, id: \.self) { residence in
                        Text(residence).tag(residence)
                    }
                }
            } label: {
                HStack {
                    Text(selectedResidence)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.8))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.gray.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(Color.secondaryBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
            }
        }
    }
    
    @ViewBuilder
    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(title: "現在地からの距離", icon: "location.fill", color: Color.thirdColor)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("距離で絞り込む")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                    Spacer()
                    Toggle("", isOn: $useDistanceFilter)
                        .tint(Color.thirdColor)
                }
                
                if useDistanceFilter {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("\(Int(searchRadius))km 以内")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.thirdColor)
                            Spacer()
                        }
                        
                        Slider(value: $searchRadius, in: 1...100, step: 1)
                            .tint(Color.thirdColor)
                    }
                    .padding(.top, 10)
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
    private var applyButton: some View {
        Button(action: {
            self.voiceChatViewModel.applyFilter(
                fromAge: Int(minAge),
                toAge: Int(maxAge),
                prefecture: selectedResidence,
                radius: Int(searchRadius),
                useDistance: useDistanceFilter
            )
            withAnimation(.spring()) {
                self.isShowWindow.toggle()
            }
        }) {
            Text("この条件で適用する")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.thirdColor)
                .clipShape(Capsule())
                .baseShadow()
                .padding(.horizontal, 40)
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
