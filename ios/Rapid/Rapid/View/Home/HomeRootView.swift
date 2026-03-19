//
//  HomeRootView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/02.
//

import Foundation
import SwiftUI
import PopupView
import SDWebImageSwiftUI

public enum HomeRoot: Equatable {
    case home
    case chatRoom
    case setting
    case editing
    case recruitment
}

struct HomeRootView: View {
    @EnvironmentObject private var mainRootViewModel: RootViewModel<MainRoot>
    
    @StateObject private var homeRootViewModel: RootViewModel<HomeRoot> = .init(root: .home)
    @StateObject private var profileViewModel = ProfileViewModel()
    @StateObject private var recruitmentViewModel = RecruitmentViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var voiceChatViewModel = VoiceChatViewModel()
    @StateObject private var notificationViewModel = NotificationViewModel()
    
    var body: some View {
        ZStack {
            RootViewController(rootViewModel: homeRootViewModel) { root in
                switch root {
                case .home:
                    HomeView()
                        .environmentObject(profileViewModel)
                        .environmentObject(chatViewModel)
                        .environmentObject(recruitmentViewModel)
                        .environmentObject(voiceChatViewModel)
                        .environmentObject(notificationViewModel)
                case .chatRoom:
                    ChatRoomRootView(chatViewModel: chatViewModel)
                        .environmentObject(profileViewModel)
                case .setting:
                    ProfileSettingView()
                        .environmentObject(profileViewModel)
                        .environmentObject(mainRootViewModel)
                        .environmentObject(notificationViewModel)
                case .editing:
                    ProfileEditingView()
                        .environmentObject(profileViewModel)
                        .environmentObject(mainRootViewModel)
                case .recruitment:
                    RecruitmentReviewView()
                        .environmentObject(recruitmentViewModel)
                }
            }
            .ignoresSafeArea()
            .navigationBarBackButtonHidden(true)
            .environmentObject(homeRootViewModel)
        }
        .popup(isPresented: $notificationViewModel.showBanner) {
            if let content = notificationViewModel.bannerContent {
                let isMessageType = content.bannerType == "message"
                let isMatchRoomId = content.customData["roomId"] == self.chatViewModel.selectedChatRoom?.chatRoom.id.uuidString.lowercased()
                
                if !(isMessageType && isMatchRoomId) {
                    notificationBanner(content: content)
                }
            }
        } customize: { view in
            view
                .type(.floater())
                .position(.top)
                .animation(.spring())
                .autohideIn(4)
        }
        .fullScreenCover(isPresented: Binding(
            get: { chatViewModel.isShowPermissionFlow || voiceChatViewModel.isShowPermissionFlow },
            set: { newValue in
                if !newValue {
                    chatViewModel.isShowPermissionFlow = false
                    voiceChatViewModel.isShowPermissionFlow = false
                }
            }
        )) {
            TalkPermissionFlowView(isIdentityVerified: chatViewModel.isIdentityVerified || voiceChatViewModel.isIdentityVerified)
                .environmentObject(chatViewModel)
                .environmentObject(voiceChatViewModel)
                .environmentObject(profileViewModel)
        }
    }
    
    @ViewBuilder
    private func notificationBanner(content: BannerContent) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(content.color.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                if let imageURL = content.imageURL {
                    WebImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Image(systemName: content.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(content.color)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text(content.body)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .baseShadow()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}
