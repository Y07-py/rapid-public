//
//  ChatListView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/10/31.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct ChatListView: View {
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    private let profileImageSize: CGFloat = 50
    private let dateFormatter = DateFormatter()
    
    @State private var isRefreshing: Bool = false
    
    var body: some View {
        Group {
            if !chatViewModel.isFetchingChatRooms {
                VStack {
                    Spacer()
                    PremiumLoadingIndicator()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if chatViewModel.sortedChatRooms.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            // Loading indicator shown only when refreshing
                            if self.isRefreshing {
                                PremiumLoadingIndicator()
                                    .padding(.vertical, 15)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                            
                            LazyVStack(spacing: 15) {
                                ForEach(chatViewModel.sortedChatRooms) { room in
                                    chatRoomRow(room: room)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y
                    } action: { oldValue, newValue in
                        // Threshold of -75 to trigger refresh
                        if newValue < 0{
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                self.isRefreshing = true
                            }
                            // Wait for actual data fetch
                            chatViewModel.refreshChatRooms()
                        } else {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                self.isRefreshing = false
                            }
                        }
                    }
                }
            }
        }
        .alert("エラー", isPresented: $chatViewModel.isShowAlertFetchingChatRooms) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("チャットルームの取得に失敗しました。通信環境を確認して再度お試しください。")
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
                
                Image("Speech Balloon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .shadow(color: .mainColor.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            
            VStack(spacing: 12) {
                Text("トークがまだありません")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text("気になる相手が見つかったら、\n積極的に募集に参加してみましょう！")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    chatViewModel.isFetchingChatRooms = false
                    chatViewModel.refreshChatRooms()
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    @ViewBuilder
    private func chatRoomRow(room: ChatRoomWithRecruitment) -> some View {
        let user = room.roomUser
        Button(action: {
            self.chatViewModel.selectedChatRoom = room
            if self.chatViewModel.isEnableTalk {
                self.homeRootViewModel.push(.chatRoom)
            } else {
                self.chatViewModel.isShowPermissionFlow = true
            }
        }) {
            HStack(alignment: .center, spacing: 15) {
                profileImage(user: user)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 0) {
                        HStack(spacing: 8) {
                            Text(user.user.userName ?? "No Name")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.black.opacity(0.8))
                            
                            if let deadline = remainingDeadline(room: room) {
                                Text(deadline)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(deadlineColor(room: room))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Spacer()
                        
                        Text(dateString(room.chatRoom.createdAt))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.gray)
                    }
                    
                    HStack(spacing: 0) {
                        if let lastMessage = room.lastMessage {
                            let isLastMessageFromToUser = room.messages.last?.fromUserId == room.roomUser.user.id
                            let shouldBlur = !chatViewModel.isEnableTalk && isLastMessageFromToUser
                            
                            Text(lastMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                                .blur(radius: shouldBlur ? 6 : 0)
                        } else {
                            Text("新しいルームが作成されました")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.gray.opacity(0.6))
                                .italic()
                        }
                        
                        Spacer()
                        
                        if room.unReadCount > 0 {
                            Text("\(room.unReadCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.thirdColor)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding(15)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondaryBackgroundColor)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func profileImage(user: RapidUserWithProfile) -> some View {
        ZStack {
            if let profileImage = user.profileImages.first {
                WebImage(url: profileImage.imageURL) { image in
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
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray)
                    }
            }
        }
    }
    
    private func dateString(_ date: Date) -> String {
        let calendar = Calendar.current
        let datediff = calendar.dateComponents([.year, .month, .day], from: date, to: .now).day!
        if datediff < 1 {
            return "今日"
        } else {
            dateFormatter.dateFormat = "MM/dd"
            return dateFormatter.string(from: date)
        }
    }
    
    private func remainingDeadline(room: ChatRoomWithRecruitment) -> String? {
        // If permanent match, no deadline
        if let talkCount = room.chatRoom.talkCount, talkCount == 0 {
            return nil
        }
        
        let now = Date()
        // 3 days window from creation
        let deadline = room.chatRoom.createdAt.addingTimeInterval(3 * 24 * 60 * 60)
        
        if deadline <= now {
            return nil // Already expired or soon to be removed
        }
        
        let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: deadline)
        
        if let day = diff.day, day > 0 {
            return "あと\(day)日"
        } else if let hour = diff.hour, hour > 0 {
            return "あと\(hour)時間"
        } else if let minute = diff.minute, minute > 0 {
            return "あと\(minute)分"
        }
        
        return "まもなく終了"
    }
    
    private func deadlineColor(room: ChatRoomWithRecruitment) -> Color {
        let now = Date()
        let deadline = room.chatRoom.createdAt.addingTimeInterval(3 * 24 * 60 * 60)
        let diff = deadline.timeIntervalSince(now)
        
        if diff < 60 * 60 * 6 { // < 6 hours
            return Color.mainColor
        } else if diff < 60 * 60 * 24 { // < 24 hours
            return Color.orange
        } else {
            return Color.blue.opacity(0.7)
        }
    }
}

// MARK: - Premium Loading Indicator
struct PremiumLoadingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.1), lineWidth: 3)
                .frame(width: 30, height: 30)
            
            Circle()
                .trim(from: 0, to: 0.6)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Color.thirdColor, Color.thirdColor.opacity(0.1)]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 30, height: 30)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .onAppear {
                    withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
        }
    }
}

// MARK: - Preference Keys
struct PullDownOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
