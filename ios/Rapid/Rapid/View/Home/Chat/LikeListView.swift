//
//  LikeListView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/10/31.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import PopupView
import Lottie

struct LikeListView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    
    @State private var isShowMatchWindow: Bool = false
    @Binding var selectedTabIndex: ChatTabIndex
    
    var body: some View {
        Group {
            if !chatViewModel.isFetchingLikers {
                VStack {
                    Spacer()
                    PremiumLoadingIndicator()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 15) {
                    Text("あなたをいいねしたユーザー")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    
                    ScrollView(.vertical) {
                        if chatViewModel.likers.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 20) {
                                ForEach(chatViewModel.likers) { liker in
                                    likerRow(liker: liker)
                                }
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 30)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .onDisappear {
            self.chatViewModel.syncReadStatus()
        }
        .alert("エラー", isPresented: $chatViewModel.isShowAlertFetchingLikers) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("データの取得に失敗しました。通信環境を確認して再度お試しください。")
        }
        .fullScreenCover(isPresented: $isShowMatchWindow) {
            MatchWindowView(isShowMatchWindow: $isShowMatchWindow, selectedTabIndex: $selectedTabIndex)
                .environmentObject(chatViewModel)
                .environmentObject(profileViewModel)
                .environmentObject(homeRootViewModel)
        }
        .fullScreenCover(item: $chatViewModel.selectedUser) { user in
            ChatUserProfileView(user: user)
                .environmentObject(chatViewModel)
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 25) {
            Spacer().frame(height: 80)
            
            ZStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Image("Thumbs Up")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .shadow(color: .mainColor.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            
            VStack(spacing: 12) {
                Text("いいねがまだありません")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text("プロフィールの写真を工夫したり、\n募集を作成して注目を集めてみましょう！")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    chatViewModel.isFetchingLikers = false
                    chatViewModel.refreshLikers()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .bold))
                    Text("再読み込み")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.thirdColor)
                        .shadow(color: Color.thirdColor.opacity(0.3), radius: 10, x: 0, y: 5)
                )
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 40)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    @ViewBuilder
    private func likerRow(liker: Liker) -> some View {
        VStack(spacing: 15) {
            HStack(alignment: .center, spacing: 15) {
                // Profile Image
                if let profileImage = liker.user.profileImages.first {
                    WebImage(url: profileImage.imageURL) { view in
                        view
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .foregroundStyle(.gray.opacity(0.1))
                            .skelton(isActive: true)
                    }
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 70, height: 70)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.gray)
                        }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(liker.user.user.userName ?? "No name")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                    
                    HStack(spacing: 12) {
                        Label("\(liker.user.user.birthDate?.computeAge() ?? 0)歳", systemImage: "person")
                        Label(liker.user.user.residence ?? "不明", systemImage: "mappin.and.ellipse")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray)
                }
                
                Spacer()
                
                Text(likedDate(createdAt: liker.likedAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.gray.opacity(0.6))
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.chatViewModel.selectedUser = liker.user
                    }
                }) {
                    HStack {
                        Image(systemName: "person.text.rectangle")
                        Text("プロフィール")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.pointBarColor)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    self.chatViewModel.selectedUser = liker.user
                    self.chatViewModel.makeChatRoom()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.isShowMatchWindow.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "hand.thumbsup.fill")
                        Text("いいねを返す")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.mainColor)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: Color.mainColor.opacity(0.4), radius: 5, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(15)
        .background {
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.secondaryBackgroundColor)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, 20)
        .onAppear {
            if let index = self.chatViewModel.likers.firstIndex(where: { $0.id == liker.id }),
               !self.chatViewModel.likers[index].isRead {
                self.chatViewModel.likers[index].isRead = true
                if self.chatViewModel.unreadLikesCount > 0 {
                    self.chatViewModel.unreadLikesCount -= 1
                }
            }
        }
    }
    
    private func likedDate(createdAt date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "ja_JP")
        let relativeString = formatter.localizedString(for: date, relativeTo: Date())
        
        return relativeString
    }
}


