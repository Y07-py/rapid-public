//
//  ChatView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/22.
//

import SwiftUI
import SlidingTabView

public enum ChatTabIndex: String, CaseIterable {
    case chatList = "Chat"
    case likeList = "Like"
}

struct ChatView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    
    @State private var selectedTabIndex: ChatTabIndex = .chatList
    @State private var tabIndex: Int = 0
    
    @Namespace private var namespace
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            // Decorative background glow
            VStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -150, y: -100)
                Spacer()
                Circle()
                    .fill(Color.selectedColor.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: 150, y: 100)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("メッセージ")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                // Custom Tab Switcher
                HStack(spacing: 0) {
                    tabButton(type: .chatList, label: "トーク", count: chatViewModel.unreadMessageCount, badgeColor: Color.thirdColor)
                    tabButton(type: .likeList, label: "いいね", count: chatViewModel.unreadLikesCount, badgeColor: .red)
                }
                .padding(5)
                .background(Color.secondaryBackgroundColor)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
                
                TabView(selection: $selectedTabIndex) {
                    ChatListView()
                        .environmentObject(chatViewModel)
                        .environmentObject(homeRootViewModel)
                        .environmentObject(profileViewModel)
                        .tag(ChatTabIndex.chatList)
                    LikeListView(selectedTabIndex: $selectedTabIndex)
                        .environmentObject(chatViewModel)
                        .environmentObject(profileViewModel)
                        .tag(ChatTabIndex.likeList)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .padding(.top, 10)
            }
        }
    }
    
    @ViewBuilder
    private func tabButton(type: ChatTabIndex, label: String, count: Int, badgeColor: Color) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.selectedTabIndex = type
            }
        }) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(badgeColor)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(selectedTabIndex == type ? .white : .gray)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                if selectedTabIndex == type {
                    Capsule()
                        .fill(Color.mainColor)
                        .matchedGeometryEffect(id: "activeTab", in: namespace)
                        .shadow(color: Color.mainColor.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

