//
//  UserNameSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/12.
//

import Foundation
import SwiftUI

struct UserNameLoginSettingView: View {
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
                    
                    Text("ユーザー名を教えてください")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(Color.primary)
                    
                    Text("他のユーザーに表示される表示名です。後から変更することはできないので注意してください。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .padding(.top, 40)
                
                // MARK: - Input Card
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ニックネーム")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        ZStack(alignment: .trailing) {
                            TextField("", text: $profileLoginSettingViewModel.userName)
                                .font(.system(size: 18, weight: .medium))
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                                .background(Color.white.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(profileLoginSettingViewModel.userName.isEmpty ? Color.gray.opacity(0.2) : Color.mainColor.opacity(0.5), lineWidth: 1.5)
                                )
                            
                            if !profileLoginSettingViewModel.userName.isEmpty {
                                Button(action: { profileLoginSettingViewModel.userName = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.gray.opacity(0.5))
                                }
                                .padding(.trailing, 16)
                            }
                        }
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .baseShadow()
                
                Spacer()
                
                // MARK: - Action Button
                Button(action: {
                    if profileLoginSettingViewModel.userName.isEmpty {
                        alert.toggle()
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            profileLoginSettingViewModel.progress += 1
                            profileLoginRootViewModel.push(.gender)
                        }
                    }
                }) {
                    Text("次へ進む")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
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
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
        .alert(isPresented: $alert) {
            Alert(title: Text("ユーザー名を入力してください"), dismissButton: .default(Text("OK")))
        }
        .ignoresSafeArea(.keyboard)
    }
}
