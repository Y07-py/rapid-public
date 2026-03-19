//
//  MatchWindowView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/03/14.
//

import SwiftUI
import SDWebImageSwiftUI
import Lottie

struct MatchWindowView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    
    @Binding var isShowMatchWindow: Bool
    @Binding var selectedTabIndex: ChatTabIndex
    
    // Allow passing the target user directly if it's not the one in chatViewModel
    var targetUser: RapidUserWithProfile?
    
    var body: some View {
        ZStack {
            Color.thirdColor.opacity(0.7).ignoresSafeArea()
            LottieView(animation: .named("Confetti.json"))
                .playbackMode(.playing(.toProgress(1, loopMode: .playOnce)))
            VStack(alignment: .center, spacing: .zero) {
                Text("マッチ成立！")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 40)
                Text("さっそくトークしてみましょう")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 20)

                Spacer()
                HStack(alignment: .center, spacing: 10) {
                    // Current User Image
                    if let currentUser = profileViewModel.user,
                        let currentUserProfileImage = currentUser.profileImages.first {
                        Circle()
                            .frame(width: 110, height: 110)
                            .foregroundStyle(.white)
                            .overlay(alignment: .center) {
                                WebImage(url: currentUserProfileImage.imageURL) { view in
                                    view
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .foregroundStyle(.gray.opacity(0.8))
                                        .skelton(isActive: true)
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 50))
                                .clipped()
                            }
                    } else {
                        Circle()
                            .frame(width: 110, height: 110)
                            .foregroundStyle(.white)
                            .overlay(alignment: .center) {
                                Image("profile-image")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .foregroundStyle(.gray)
                            }
                    }
                    
                    // Target User Image
                    let displayUser = targetUser ?? chatViewModel.selectedUser
                    if let user = displayUser,
                       let targetUserProfileImage = user.profileImages.first {
                        Circle()
                            .frame(width: 110, height: 110)
                            .foregroundStyle(.white)
                            .overlay(alignment: .center) {
                                WebImage(url: targetUserProfileImage.imageURL) { view in
                                    view
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .foregroundStyle(.gray.opacity(0.8))
                                        .skelton(isActive: true)
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 50))
                                .clipped()
                            }
                    } else {
                        Circle()
                            .frame(width: 110, height: 110)
                            .foregroundStyle(.white)
                            .overlay(alignment: .center) {
                                Image("profile-image")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .foregroundStyle(.gray)
                            }
                    }
                }
                VStack(alignment: .center, spacing: 5) {
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            // If we came from Recruitment, we might need to set the selected user in chatViewModel
                            if let user = targetUser {
                                self.chatViewModel.selectedUser = user
                                self.chatViewModel.setSelectedChatRoom(withUserId: user.user.id)
                            }
                            
                            if self.chatViewModel.isEnableTalk {
                                self.homeRootViewModel.push(.chatRoom)
                                self.selectedTabIndex = .chatList
                            } else {
                                self.chatViewModel.isShowPermissionFlow = true
                            }
                            self.isShowMatchWindow.toggle()
                        }
                        
                    }) {
                        RoundedRectangle(cornerRadius: 20)
                            .foregroundStyle(.white)
                            .frame(height: 50)
                            .padding(10)
                            .overlay {
                                Text("メッセージを送る")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.thirdColor)
                            }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.isShowMatchWindow.toggle()
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 20)
                            .foregroundStyle(.white)
                            .frame(height: 50)
                            .padding(10)
                            .overlay {
                                Text("閉じる")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.thirdColor)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                Spacer()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
