//
//  KeyWordTagSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/19.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct KeyWordTagSettingView: View {
    @EnvironmentObject private var settingRootViewModel: RootViewModel<ProfileLoginSettingRoot>
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color.backgroundColor.ignoresSafeArea()
            
            // Background Glows
            ZStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(x: 120, y: -150)
                
                Circle()
                    .fill(Color.selectedColor.opacity(0.15))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: -120, y: 120)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 32) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interests")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.mainColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.mainColor.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Text("趣味について教えてください")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(Color.primary)
                    
                    Text("あなたが何に関心があるかを伝えるためのキーワードです。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // MARK: - Input Card
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        let keywordTags = profileLoginSettingViewModel.keywordTags
                        ForEach(Array(keywordTags.keys).sorted(), id: \.self) { category in
                            VStack(alignment: .leading, spacing: 16) {
                                Text(category)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.primary.opacity(0.8))
                                
                                FlowLayout(spacing: 12) {
                                    if let keywords = keywordTags[category] {
                                        ForEach(keywords) { keywordTag in
                                            let isSelected = profileLoginSettingViewModel.selectedKeyWordTags.contains(where: { $0.keyword == keywordTag.keyword })
                                            
                                            Button(action: {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                    profileLoginSettingViewModel.toggleKeyWordTag(tag: keywordTag)
                                                }
                                            }) {
                                                Text(keywordTag.keyword)
                                                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .foregroundStyle(isSelected ? .white : .primary.opacity(0.7))
                                                    .background(
                                                        isSelected ?
                                                        LinearGradient(colors: [Color.mainColor.opacity(0.9), Color.mainColor], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                                        LinearGradient(colors: [Color.white.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                    )
                                                    .clipShape(Capsule())
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                                                    )
                                                    .baseShadow()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .baseShadow()
                    .padding(.bottom, 20)
                    .padding(.horizontal, 10)
                }
                
                Spacer()
                
                // MARK: - Navigation Buttons
                HStack(spacing: 16) {
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
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            settingRootViewModel.push(.introduction)
                            profileLoginSettingViewModel.progress += 1
                        }
                    }) {
                        Text("次へ進む")
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
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
    }
}
