//
//  VoiceChatMatchListView.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/16.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import PopupView

struct VoiceChatMatchListView: View {
    @EnvironmentObject private var voiceChatViewModel: VoiceChatViewModel
    
    @Binding var isShowWindow: Bool
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            // Decorative background glows
            VStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(x: -160, y: -80)
                Spacer()
                Circle()
                    .fill(Color.thirdColor.opacity(0.15))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 160, y: 80)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .center, spacing: .zero) {
                headerView
                MatchedUserListView()
                    .environmentObject(voiceChatViewModel)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("マッチしたユーザー")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    self.isShowWindow.toggle()
                }
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }
}

fileprivate struct MatchedUserListView: View {
    @EnvironmentObject private var voiceChatViewModel: VoiceChatViewModel
    
    @State private var selectedUser: RapidUserWithProfile? = nil
    
    // Voice chat property
    @State private var signalingClient: SignalingClient? = nil
    @State private var isShowCallWaitingView: Bool = false
    @State private var clientId: String = ""
    @State private var callId: String = ""
    
    var body: some View {
        ZStack {
            if voiceChatViewModel.isFetchingMatchedUsers {
                ProgressView()
                    .padding(.top, 50)
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .center, spacing: 16) {
                        let matchedUsers = voiceChatViewModel.matchedVoiceChatUsers
                        if matchedUsers.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.gray.opacity(0.3))
                                Text("まだマッチはありません")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                            .padding(.top, 100)
                        } else {
                            ForEach(matchedUsers) { profile in
                                matchedUserRow(profile: profile)
                            }
                        }
                        
                        Spacer().frame(height: 50)
                    }
                    .padding(.top, 10)
                }
                .scrollIndicators(.hidden)
            }
        }
        .fullScreenCover(isPresented: $isShowCallWaitingView, content: {
            VoiceChatCallView(
                isPresented: $isShowCallWaitingView,
                signalingClient: signalingClient,
                clientId: clientId,
                callId: callId,
                role: .caller,
                opponentName: selectedUser?.user.userName,
                opponentImageURL: selectedUser?.profileImages.first?.imageURL
            )
        })
        .popup(item: $selectedUser) { profile in
            talkConfirmationView(profile: profile)
        } customize: { view in
            view
                .type(.floater())
                .position(.center)
                .appearFrom(.centerScale)
                .backgroundColor(.black.opacity(0.3))
                .allowTapThroughBG(false)
                .animation(.smooth)
                .closeOnTapOutside(true)
                .closeOnTap(false)
        }
    }
    
    @ViewBuilder
    private func matchedUserRow(profile: RapidUserWithProfile) -> some View {
        HStack(alignment: .center, spacing: 16) {
            if let photo = profile.profileImages.first {
                WebImage(url: photo.imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .foregroundStyle(.gray.opacity(0.1))
                        .skelton(isActive: true)
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.user.userName ?? "No Name")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
                
                Text("\(profile.user.birthDate?.computeAge() ?? 0)歳 • \(profile.user.residence ?? "未設定")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Button(action: {
                self.selectedUser = profile
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("話す")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.thirdColor)
                .clipShape(Capsule())
                .shadow(color: Color.thirdColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private func talkConfirmationView(profile: RapidUserWithProfile) -> some View {
        VStack(alignment: .center, spacing: 20) {
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        self.selectedUser = nil
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            
            VStack(spacing: 16) {
                if let photo = profile.profileImages.first {
                    WebImage(url: photo.imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().foregroundStyle(.gray.opacity(0.1)).skelton(isActive: true)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                
                VStack(spacing: 8) {
                    Text("\(profile.user.userName ?? "No Name")")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                    
                    Text("ボイスチャットを開始しますか？")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.gray)
                }
            }
            
            VStack(alignment: .center, spacing: 10) {
                Text("• 相手がオフラインの場合は通話できません")
                Text("• いつでも通話を終了できます")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.gray.opacity(0.6))
            .padding(.horizontal, 20)
            
            Button(action: {
                self.voiceChatViewModel.sendCallMessage(profile: profile) { client, callId, clientId in
                    self.signalingClient = client
                    self.clientId = clientId
                    self.callId = callId
                    self.signalingClient?.connect()
                    withAnimation {
                        self.isShowCallWaitingView = true
                        self.selectedUser = nil
                    }
                }
            }) {
                Text("開始する")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.thirdColor)
                    .clipShape(Capsule())
                    .shadow(color: Color.thirdColor.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .padding(.horizontal, 30)
    }
}
