//
//  BirthdayLoginSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/12.
//

import Foundation
import SwiftUI

struct BirthdayLoginSettingView: View {
    @EnvironmentObject private var settingRootViewModel: RootViewModel<ProfileLoginSettingRoot>
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color.backgroundColor.ignoresSafeArea()
            
            // Background Glows
            ZStack {
                Circle()
                    .fill(Color.selectedColor.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -100, y: -100)
                
                Circle()
                    .fill(Color.mainColor.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 50)
                    .offset(x: 100, y: 150)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 32) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Basic Info")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.selectedColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.selectedColor.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Text("生年月日を教えてください")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(Color.primary)
                    
                    Text("年齢を確認するために必要です。この情報は後から変更ができませんのでご注意ください。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .padding(.top, 40)
                
                // MARK: - Input Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("誕生日")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    DatePicker(
                        "",
                        selection: $profileLoginSettingViewModel.birthday,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
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
                            settingRootViewModel.push(.height)
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
