//
//  CompleteSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/20.
//

import Foundation
import SwiftUI

struct CompleteSettingView: View {
    @EnvironmentObject private var settingRootViewModel: RootViewModel<ProfileLoginSettingRoot>
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    
    @State private var showCheckmark: Bool = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color.backgroundColor.ignoresSafeArea()
            
            // Background Glows
            ZStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.15))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: -120, y: -200)
                
                Circle()
                    .fill(Color.selectedColor.opacity(0.12))
                    .frame(width: 350, height: 350)
                    .blur(radius: 70)
                    .offset(x: 150, y: 150)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // MARK: - Status Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 140, height: 140)
                        .baseShadow()
                    
                    if profileLoginSettingViewModel.isProcessing {
                        VStack(spacing: 20) {
                            ProgressView()
                                .controlSize(.large)
                                .tint(Color.mainColor)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else if profileLoginSettingViewModel.didComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.mainColor, Color.mainColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(showCheckmark ? 1.0 : 0.5)
                            .opacity(showCheckmark ? 1.0 : 0.0)
                            .transition(.asymmetric(insertion: .scale, removal: .opacity))
                    }
                }
                .scaleEffect(scale)
                .opacity(opacity)
                
                // MARK: - Text Content
                VStack(spacing: 16) {
                    Text(profileLoginSettingViewModel.isProcessing ? "プロフィールを保存中..." : "設定が完了しました！")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(profileLoginSettingViewModel.isProcessing ? "もう少々お待ちください" : "Rapidへようこそ！\n素敵な出会いが見つかりますように。")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 40)
                .offset(y: opacity == 1.0 ? 0 : 20)
                .opacity(opacity)
                
                Spacer()
                
                // MARK: - Bottom Gradient Bar
                if profileLoginSettingViewModel.didComplete {
                    Text("自動的にホーム画面へ移動します...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.bottom, 40)
                        .transition(.opacity)
                }
            }
        }
        .task {
            // Start the completion process
            await profileLoginSettingViewModel.loginComplete()
        }
        .onChange(of: profileLoginSettingViewModel.didComplete) { _, completed in
            if completed {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showCheckmark = true
                }
                
                // Delay then navigate to Home
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    navigateToHome()
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    private func navigateToHome() {
        NotificationCenter.default.post(
            name: .pushRootViewNotification,
            object: nil,
            userInfo: ["root": MainRoot.home]
        )
    }
}
