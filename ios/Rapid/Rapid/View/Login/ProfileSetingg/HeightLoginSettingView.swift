//
//  HeightLoginSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/12.
//

import Foundation
import SwiftUI

struct HeightLoginSettingView: View {
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
                    Text("Body Info")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.mainColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.mainColor.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Text("身長を教えてください")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(Color.primary)
                    
                    Text("あなたの個性を彩る情報の一つです。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // MARK: - Input Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("身長 (cm)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    Picker("身長", selection: $profileLoginSettingViewModel.height) {
                        Text("140cm未満").tag(139)
                        ForEach(140..<221, id: \.self) { h in
                            Text("\(h)cm").tag(h)
                        }
                        Text("220cm以上").tag(221)
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
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
                            settingRootViewModel.push(.living)
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
