//
//  GenderLoginSettingView.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/08.
//

import Foundation
import SwiftUI

struct GenderLoginSettingView: View {
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    @EnvironmentObject private var profileLoginRootViewModel: RootViewModel<ProfileLoginSettingRoot>
    
    @State private var alert: Bool = false
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color.backgroundColor.ignoresSafeArea()
            
            // Background Glows
            ZStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -100, y: -200)
                
                Circle()
                    .fill(Color.selectedColor.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 50)
                    .offset(x: 150, y: 100)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 32) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("About You")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.mainColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.mainColor.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Text("性別を教えてください")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(Color.primary)
                    
                    Text("プロフィールに表示される性別です。一度設定すると変更できないため、正確に選択してください。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .padding(.top, 40)
                
                // MARK: - Selection List
                VStack(spacing: 12) {
                    ForEach(profileLoginSettingViewModel.sexList) { sex in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                profileLoginSettingViewModel.selectedGender = sex
                            }
                        }) {
                            HStack {
                                Text(sex.type.rawValue)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(profileLoginSettingViewModel.selectedGender == sex ? .white : .primary)
                                
                                Spacer()
                                
                                if profileLoginSettingViewModel.selectedGender == sex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white)
                                } else {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                }
                            }
                            .padding(.vertical, 20)
                            .padding(.horizontal, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(profileLoginSettingViewModel.selectedGender == sex ? Color.mainColor : Color.white.opacity(0.5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(profileLoginSettingViewModel.selectedGender == sex ? Color.mainColor : Color.gray.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .scaleEffect(profileLoginSettingViewModel.selectedGender == sex ? 1.02 : 1.0)
                    }
                }
                .baseShadow()
                
                Spacer()
                
                // MARK: - Navigation Buttons
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            profileLoginSettingViewModel.progress -= 1
                            profileLoginRootViewModel.pop(1)
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.mainColor)
                            .frame(width: 60, height: 60)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .baseShadow()
                    }
                    
                    Button(action: {
                        if profileLoginSettingViewModel.selectedGender == nil {
                            alert.toggle()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                profileLoginSettingViewModel.progress += 1
                                profileLoginRootViewModel.push(.birthDay)
                            }
                        }
                    }) {
                        Text("次へ進む")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
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
        .alert(isPresented: $alert) {
            Alert(title: Text("性別を選択してください"), dismissButton: .default(Text("OK")))
        }
    }
}
