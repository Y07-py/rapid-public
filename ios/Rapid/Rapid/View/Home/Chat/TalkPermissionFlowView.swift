//
//  TalkPermissionFlowView.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/14.
//

import SwiftUI

enum TalkPermissionRoot: Equatable {
    case identity
    case plan
}

struct TalkPermissionFlowView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var voiceChatViewModel: VoiceChatViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @StateObject private var rootViewModel: RootViewModel<TalkPermissionRoot>
    
    init(isIdentityVerified: Bool) {
        let initialRoot: TalkPermissionRoot = isIdentityVerified ? .plan : .identity
        _rootViewModel = StateObject(wrappedValue: RootViewModel(root: initialRoot))
    }
    
    var body: some View {
        ZStack {
            RootViewController(rootViewModel: rootViewModel) { root in
                switch root {
                case .identity:
                    TalkPermissionIdentityStepView()
                        .environmentObject(rootViewModel)
                        .environmentObject(chatViewModel)
                        .environmentObject(voiceChatViewModel)
                        .environmentObject(profileViewModel)
                case .plan:
                    TalkPermissionPlanStepView()
                        .environmentObject(rootViewModel)
                        .environmentObject(chatViewModel)
                        .environmentObject(voiceChatViewModel)
                        .environmentObject(profileViewModel)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Step 1: Identity Verification
struct TalkPermissionIdentityStepView: View {
    @EnvironmentObject var rootViewModel: RootViewModel<TalkPermissionRoot>
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var voiceChatViewModel: VoiceChatViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    
    @State private var isShowIdentificationView: Bool = false
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 30) {
                HStack {
                    Button(action: {
                        chatViewModel.isShowPermissionFlow = false
                        voiceChatViewModel.isShowPermissionFlow = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.black.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .background(Color.secondaryBackgroundColor)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.selectedColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.selectedColor)
                }
                
                VStack(spacing: 12) {
                    Text("Step 1: 本人確認")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.black.opacity(0.8))
                    
                    Text("安全にトークをご利用いただくために、\nまずは公的証明書による本人確認が必要です。")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                
                Spacer()
                
                let isAuthenticating = profileViewModel.user?.user.identityVerifiedStatus == "authenticating"
                
                Button(action: {
                    isShowIdentificationView = true
                }) {
                    Text(isAuthenticating ? "審査状況を確認する" : "本人確認を開始する")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(isAuthenticating ? Color.blue : Color.selectedColor)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .baseShadow()
                }
                .padding(.horizontal, 25)
                
                if !chatViewModel.isWoman {
                    Button(action: {
                        // Skip for debugging or if user wants to see the next step check
                        // In production, this should only happen if isIdentityVerified matches
                        rootViewModel.push(.plan)
                    }) {
                        Text("確認済みの方はこちら")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.gray)
                    }
                    .padding(.bottom, 30)
                } else {
                    Spacer().frame(height: 30)
                }
            }
        }
        .fullScreenCover(isPresented: $isShowIdentificationView) {
            ProfileIdentityVeriticationView(isShowWindow: $isShowIdentificationView)
                .environmentObject(profileViewModel)
                .onDisappear {
                    // Check if verified after coming back
                    Task {
                        await chatViewModel.checkEnableTalk()
                        await voiceChatViewModel.checkEnableTalk()
                        if chatViewModel.isIdentityVerified {
                            if chatViewModel.isWoman {
                                chatViewModel.isShowPermissionFlow = false
                                voiceChatViewModel.isShowPermissionFlow = false
                            } else {
                                withAnimation {
                                    rootViewModel.push(.plan)
                                }
                            }
                        }
                    }
                }
        }
    }
}

// MARK: - Step 2: Plan Purchase
struct TalkPermissionPlanStepView: View {
    @EnvironmentObject var rootViewModel: RootViewModel<TalkPermissionRoot>
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var voiceChatViewModel: VoiceChatViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    
    @State private var isShowPremiumPayWall: Bool = false
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 30) {
                HStack {
                    Button(action: {
                        rootViewModel.pop(1)
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.black.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .background(Color.secondaryBackgroundColor)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.mainColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.mainColor)
                }
                
                VStack(spacing: 12) {
                    Text("Step 2: プランの購入")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.black.opacity(0.8))
                    
                    Text("トークを無制限に利用するには、\nプランへの加入が必要です。")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                
                Spacer()
                
                Button(action: {
                    isShowPremiumPayWall = true
                }) {
                    Text("プランの詳細を見る")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.mainColor)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .baseShadow()
                }
                .padding(.horizontal, 25)
                
                Button(action: {
                    chatViewModel.isShowPermissionFlow = false
                    voiceChatViewModel.isShowPermissionFlow = false
                }) {
                    Text("あとで")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.gray)
                }
                .padding(.bottom, 30)
            }
        }
        .fullScreenCover(isPresented: $isShowPremiumPayWall) {
            PremiumPayWallView(isPresented: $isShowPremiumPayWall)
                .environmentObject(profileViewModel)
                .onDisappear {
                    Task {
                        await chatViewModel.checkEnableTalk()
                        await voiceChatViewModel.checkEnableTalk()
                        if chatViewModel.isEnableTalk {
                            chatViewModel.isShowPermissionFlow = false
                            voiceChatViewModel.isShowPermissionFlow = false
                        }
                    }
                }
        }
    }
}
