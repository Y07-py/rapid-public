//
//  VoiceChatView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/18.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import Lottie

struct VoiceChatView: View {
    @EnvironmentObject private var voiceChatViewModel: VoiceChatViewModel
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @State private var isShowDetailView: Bool = false
    @State private var isShowFilterView: Bool = false
    @State private var isShowMatchListView: Bool = false
    
    @Namespace private var namespace
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            // Decorative background glows
            VStack {
                Circle()
                    .fill(Color.thirdColor.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -150, y: -100)
                Spacer()
                Circle()
                    .fill(Color.mainColor.opacity(0.12))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: 150, y: 100)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .center, spacing: .zero) {
                headerView
                
                if voiceChatViewModel.voiceChatRooms.isEmpty && voiceChatViewModel.votingEvent == nil {
                    emptyStateView
                } else {
                    if voiceChatViewModel.isWaitingForVoiceChat {
                        VoiceChatWaitingView()
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        ScrollView(.vertical) {
                            VStack(alignment: .center, spacing: 20) {
                                if let event = voiceChatViewModel.votingEvent {
                                    if event.status == "voting" {
                                        VoiceChatVotingView()
                                            .environmentObject(voiceChatViewModel)
                                            .environmentObject(profileViewModel)
                                    } else if event.status == "starting" {
                                        VoiceChatMatchingResultView()
                                            .environmentObject(voiceChatViewModel)
                                    }
                                }
                                
                                Spacer().frame(height: 120)
                            }
                            .padding(.top, 10)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .fullScreenCover(isPresented: $isShowDetailView) {
                VoiceChatDetailView(isShowDetailView: $isShowDetailView)
                    .environmentObject(voiceChatViewModel)
            }
            .sheet(isPresented: $isShowFilterView) {
                VoiceChatFilterView(isShowWindow: $isShowFilterView)
                    .environmentObject(voiceChatViewModel)
                    .presentationDetents([.fraction(0.8), .large])
                    .presentationDragIndicator(.visible)
            }
            
            if voiceChatViewModel.isJoinLeaveLoading {
                LoadingOverlayView()
            }
        }
        .alert("マイクへのアクセスが拒否されています", isPresented: $voiceChatViewModel.isShowMicrophoneAlert) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ボイスチャットを楽しむには、設定からマイクへのアクセスを許可してください。")
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ボイスチャット")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text("リアルタイムで繋がる")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 15)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.thirdColor.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Color.thirdColor.opacity(0.6))
            }
            
            VStack(spacing: 12) {
                Text("ボイスチャットがありません")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text("現在、募集中のルームはありません。")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.bottom, 100)
    }
}
