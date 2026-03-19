//
//  IntroductionSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/12.
//

import Foundation
import SwiftUI

struct IntroductionSettingView: View {
    @EnvironmentObject private var settingRootViewModel: RootViewModel<ProfileLoginSettingRoot>
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    
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
                // MARK: - Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bio")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.selectedColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.selectedColor.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Text("自己紹介を書きましょう")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(Color.primary)
                    
                    Text("あなたの趣味や休日の過ごし方など、自由に書いてみてください。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // MARK: - Input Card
                VStack(alignment: .trailing, spacing: 12) {
                    ZStack(alignment: .topLeading) {
                        if profileLoginSettingViewModel.introduction.isEmpty {
                            Text("例：はじめまして！旅行とカフェ巡りが好きです。よろしくお願いします。")
                                .font(.system(size: 16))
                                .foregroundStyle(.gray.opacity(0.5))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        
                        TextEditor(text: $profileLoginSettingViewModel.introduction)
                            .focused($focus)
                            .font(.system(size: 16, weight: .medium))
                            .lineSpacing(6)
                            .scrollContentBackground(.hidden)
                            .autocorrectionDisabled(true)
                    }
                    .frame(height: 240)
                    
                    Text("\(profileLoginSettingViewModel.introduction.count) 文字")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(profileLoginSettingViewModel.introduction.isEmpty ? .secondary : Color.mainColor)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .baseShadow()
                
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
                            settingRootViewModel.push(.profileImage)
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
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.focus = false
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}
