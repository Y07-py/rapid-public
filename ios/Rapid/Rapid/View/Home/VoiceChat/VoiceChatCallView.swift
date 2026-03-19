//
//  VoiceChatCallView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/22.
//

import Foundation
import SwiftUI
import WebRTC
import SDWebImageSwiftUI

struct VoiceChatCallView: View {
    @EnvironmentObject private var voiceChatViewModel: VoiceChatViewModel
    @StateObject private var videoCallViewModel: VideoCallViewModel
    @Binding var isPresented: Bool
    @State private var dotOpacity: Double = 1.0
    private var role: CallingRole
    private var opponentName: String?
    private var opponentImageURL: URL?
    
    @State private var connectingCountdown = 5
    @State private var isCountdownFinished = false
    
    init(
        isPresented: Binding<Bool>,
        signalingClient: SignalingClient?,
        clientId: String,
        callId: String,
        role: CallingRole,
        opponentName: String? = nil,
        opponentImageURL: URL? = nil
    ) {
        self._videoCallViewModel = StateObject(wrappedValue: VideoCallViewModel(signalingClient: signalingClient, callId: callId, role: role))
        self._isPresented = isPresented
        self.role = role
        self.opponentName = opponentName
        self.opponentImageURL = opponentImageURL
    }
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            // Background Decorative Elements: Dots Grid
            dotGridView
            
            // Decorative Glows
            glowLayer
            
            VStack(alignment: .center, spacing: .zero) {
                // Header Section: Remaining Time
                headerSection
                
                Spacer()
                
                // Main Content Area: User Account Card
                userAccountCard
                
                Spacer()
                
                // Footer Controls Section
                footerControls
            }
            .padding(.bottom, 60)
            
            // Connecting Overlay
            if !isCountdownFinished || videoCallViewModel.connectionState != .connected {
                ZStack {
                    Color.backgroundColor.opacity(0.9)
                        .ignoresSafeArea()
                        .background(.ultraThinMaterial)
                    
                    VStack(spacing: 32) {
                        ProgressView()
                            .tint(Color.mainColor)
                            .scaleEffect(1.5)
                        
                        VStack(spacing: 12) {
                            Text(!isCountdownFinished ? "接続中... (\(connectingCountdown))" : (role == .caller ? "呼び出し中..." : "接続中..."))
                                .font(.system(size: 20, weight: .black))
                                .kerning(-0.5)
                                .foregroundStyle(.black.opacity(0.8))
                            
                            Text("まもなく通話が開始されます")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.gray)
                        }
                        
                        Button(action: {
                            videoCallViewModel.close()
                            withAnimation {
                                isPresented = false
                            }
                        }) {
                            Text("キャンセル")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.gray)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 32)
                                .background(Color.white.opacity(0.5))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 20)
                    }
                }
            }
        }
        .onAppear {
            // Drop waiting screen after a short delay so the CallView is fully up
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                voiceChatViewModel.isWaitingForVoiceChat = false
            }
            
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                if self.connectingCountdown > 0 {
                    self.connectingCountdown -= 1
                } else {
                    timer.invalidate()
                    withAnimation {
                        self.isCountdownFinished = true
                    }
                    
                    // Start call after countdown
                    switch self.role {
                    case .caller:
                        self.videoCallViewModel.startOffer()
                    case .callee:
                        self.videoCallViewModel.answer()
                    }
                }
            }
        }
        .onChange(of: videoCallViewModel.isCallEnded) { isEnded in
            if isEnded {
                withAnimation {
                    self.voiceChatViewModel.isShowCallView = false
                    self.isPresented = false
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var dotGridView: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 48
            let columns = Int(geo.size.width / spacing) + 1
            let rows = Int(geo.size.height / spacing) + 1
            
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(0..<rows, id: \.self) { _ in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { _ in
                            Circle()
                                .fill(Color.black.opacity(0.05))
                                .frame(width: 2, height: 2)
                        }
                    }
                }
            }
            .padding(20)
        }
        .ignoresSafeArea()
    }
    
    private var glowLayer: some View {
        ZStack {
            Circle()
                .fill(Color.mainColor.opacity(0.1))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(x: -200, y: -400)
            
            Circle()
                .fill(Color.mainColor.opacity(0.1))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(x: 200, y: 400)
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("残り時間")
                    .font(.system(size: 10, weight: .black))
                    .kerning(2)
                    .foregroundStyle(.black.opacity(0.4))
                
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.5))
                    Text(videoCallViewModel.formatRemainingTime())
                        .font(.system(size: 14, weight: .black))
                        .kerning(-0.5)
                        .foregroundStyle(.black.opacity(0.8))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.top, 40)
    }
    
    private var userAccountCard: some View {
        VStack(spacing: 40) {
            // Profile Image Section
            ZStack {
                // Subtle Glow behind avatar
                Circle()
                    .fill(Color.mainColor.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)
                
                let profileImageURL = voiceChatViewModel.selectedVoiceChatRoom?.profile.profileImages.first?.imageURL ?? opponentImageURL
                
                if let url = profileImageURL {
                    WebImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(.white.opacity(0.6))
                    }
                    .frame(width: 128, height: 128)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
                    .baseShadow()
                } else {
                    Circle()
                        .fill(.white.opacity(0.6))
                        .frame(width: 128, height: 128)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.black.opacity(0.05))
                        )
                        .baseShadow()
                }
            }
            
            // Name and Status
            VStack(spacing: 16) {
                let name = voiceChatViewModel.selectedVoiceChatRoom?.profile.user.userName ?? opponentName ?? "名前なし"
                Text(name)
                    .font(.system(size: 48, weight: .black))
                    .kerning(-2)
                    .foregroundStyle(.black.opacity(0.9))
                
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.mainColor)
                        .frame(width: 6, height: 6)
                        .opacity(dotOpacity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                dotOpacity = 0.3
                            }
                        }
                    
                    Text("通話中")
                        .font(.system(size: 10, weight: .black))
                        .kerning(2.5)
                        .foregroundStyle(.black.opacity(0.4))
                }
            }
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 64)
                .fill(Color.secondaryBackgroundColor.opacity(0.4))
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 64)
                        .stroke(.white.opacity(0.6), lineWidth: 1)
                )
        }
        .padding(.horizontal, 32)
        .baseShadow()
    }
    
    private var footerControls: some View {
        HStack(spacing: 24) {
            // Mute Control
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    videoCallViewModel.toggleMute()
                }
            }) {
                Circle()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(videoCallViewModel.isMuted ? Color.mainColor : .white.opacity(0.4))
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.6), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: videoCallViewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(videoCallViewModel.isMuted ? .white : .black)
                    )
                    .baseShadow()
            }
            .buttonStyle(.plain)
            
            // Terminate Call Button
            Button(action: {
                videoCallViewModel.close()
                withAnimation {
                    isPresented = false
                }
            }) {
                HStack(spacing: 16) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text("通話終了")
                        .font(.system(size: 12, weight: .black))
                        .kerning(2)
                }
                .padding(.horizontal, 40)
                .frame(height: 64)
                .background(Color.mainColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .baseShadow()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
    }
}
