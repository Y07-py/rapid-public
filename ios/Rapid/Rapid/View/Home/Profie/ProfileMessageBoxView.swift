//
//  ProfileMessageBoxView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/27.
//

import Foundation
import SwiftUI

struct ProfileMessageBoxView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @Binding var isShowWindow: Bool
    
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
                    .offset(x: 150, y: -100)
                Spacer()
                Circle()
                    .fill(Color.selectedColor.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: -150, y: 100)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .center, spacing: .zero) {
                headerView
                
                if profileViewModel.notificationMessages.isEmpty {
                    emptyStateView
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(profileViewModel.notificationMessages) { message in
                                notificationMessageView(message: message)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 15)
                        .padding(.bottom, 50)
                    }
                }
            }
        }
        .onDisappear {
            profileViewModel.updateMessage()
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("メールボックス")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                if profileViewModel.unReadNotoficationMessageCount > 0 {
                    Text("\(profileViewModel.unReadNotoficationMessageCount)件の未読メッセージ")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.selectedColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.selectedColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowWindow.toggle()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color.secondaryBackgroundColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 25) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.05))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.mainColor.opacity(0.5), Color.selectedColor.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            
            VStack(spacing: 10) {
                Text("メッセージはありません")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.7))
                
                Text("運営からのお知らせや審査結果が\nここに表示されます")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
    }
    
    @ViewBuilder
    private func notificationMessageView(message: NotificationMessage) -> some View {
        HStack(alignment: .top, spacing: 15) {
            // Icon side
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(messageIconBackgroundColor(type: message.messageType))
                    .frame(width: 48, height: 48)
                
                Image(systemName: messageIconName(type: message.messageType))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(messageIconColor(type: message.messageType))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(messageTitle(type: message.messageType))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(messageIconColor(type: message.messageType))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(messageIconColor(type: message.messageType).opacity(0.1))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Text(timeAgoString(from: message.createdAt))
                        .font(.system(size: 12))
                        .foregroundStyle(.gray.opacity(0.5))
                }
                
                Text(message.message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.75))
                    .lineSpacing(4)
            }
            
            if !message.isRead {
                Circle()
                    .fill(Color.selectedColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.selectedColor.opacity(0.4), radius: 4, x: 0, y: 2)
                    .padding(.top, 4)
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.secondaryBackgroundColor)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(message.isRead ? Color.clear : Color.selectedColor.opacity(0.1), lineWidth: 1.5)
        )
        .onAppear {
            if !message.isRead {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let idx = self.profileViewModel.notificationMessages.firstIndex(where: { $0.id == message.id }) {
                        if !self.profileViewModel.notificationMessages[idx].isRead {
                            withAnimation {
                                self.profileViewModel.notificationMessages[idx].isRead = true
                                self.profileViewModel.unReadNotoficationMessageCount = max(0, self.profileViewModel.unReadNotoficationMessageCount - 1)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func messageIconName(type: String) -> String {
        switch type.lowercased() {
        case "system": return "gearshape.fill"
        case "info": return "info.circle.fill"
        case "success": return "checkmark.seal.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "image_review": return "face.dashed.fill"
        case "like", "like_voice_chat_room": return "heart.fill"
        default: return "bell.fill"
        }
    }
    
    private func messageIconBackgroundColor(type: String) -> Color {
        return messageIconColor(type: type).opacity(0.12)
    }
    
    private func messageIconColor(type: String) -> Color {
        switch type.lowercased() {
        case "system": return Color.gray
        case "info": return Color.blue
        case "success": return Color.mainColor
        case "warning": return Color.orange
        case "image_review": return Color.selectedColor
        case "like", "like_voice_chat_room": return Color.red
        default: return Color.selectedColor
        }
    }
    
    private func messageTitle(type: String) -> String {
        switch type.lowercased() {
        case "system": return "システム"
        case "info": return "お知らせ"
        case "success": return "完了"
        case "warning": return "注意"
        case "image_review": return "審査結果"
        case "like", "like_voice_chat_room": return "いいね"
        default: return "通知"
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
