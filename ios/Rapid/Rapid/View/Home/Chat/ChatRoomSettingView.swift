//
//  ChatRoomSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/08.
//

import Foundation
import SwiftUI
import PopupView
import SDWebImageSwiftUI

struct ChatRoomSettingView: View {
    @EnvironmentObject var chatRoomRootViewModel: RootViewModel<ChatRoomRoot>
    @EnvironmentObject var homeRootViewModel: RootViewModel<HomeRoot>
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var chatRoomViewModel: ChatRoomViewModel
    
    @State private var isReportBlockWindow: Bool = false
    @State private var isNotificationWindow: Bool = false
    @State private var isMediaWindow: Bool = false
    
    var body: some View {
        ZStack {
            Color.secondaryBackgroundColor.ignoresSafeArea()
            VStack(alignment: .center, spacing: .zero) {
                headerView
                    .background(Color.secondaryBackgroundColor)
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                    .zIndex(1)
                
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(spacing: 8) {
                            sectionItem(title: "メディア・リンク", icon: "photo.on.rectangle", color: .blue) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.isMediaWindow.toggle()
                                }
                            }
                            
                            sectionItem(title: "通知設定", icon: "bell.badge.fill", color: .orange) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.isNotificationWindow.toggle()
                                }
                            }
                        }
                        .padding(.top, 24)
                        
                        Text("プライバシーとサポート")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        
                        VStack(spacing: 8) {
                            sectionItem(title: "通報とブロック", icon: "shield.fill", color: .red) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.isReportBlockWindow.toggle()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .fullScreenCover(isPresented: $isReportBlockWindow) {
            ReportBlockView(isShowWindow: $isReportBlockWindow)
                .environmentObject(chatRoomViewModel)
                .environmentObject(chatViewModel)
                .environmentObject(homeRootViewModel)
                .environmentObject(chatRoomRootViewModel)
        }
        .fullScreenCover(isPresented: $isNotificationWindow) {
            NotificationView(isShowWindow: $isNotificationWindow)
                .environmentObject(chatRoomViewModel)
        }
        .fullScreenCover(isPresented: $isMediaWindow) {
            MediaView(isShowWindow: $isMediaWindow)
                .environmentObject(chatRoomViewModel)
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    chatRoomRootViewModel.pop(1)
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("チャット設定")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black.opacity(0.85))
            
            Spacer()
            
            // Placeholder for symmetry
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .bold))
                .opacity(0)
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }
    
    @ViewBuilder
    private func sectionItem(title: String, icon: String, color: Color, completion: @escaping () -> Void) -> some View {
        Button(action: completion) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct ReportBlockView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var chatRoomViewModel: ChatRoomViewModel
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    @EnvironmentObject private var chatRoomRootViewModel: RootViewModel<ChatRoomRoot>
    
    @Binding var isShowWindow: Bool
    
    @State private var isShowBlockAlert: Bool = false
    @State private var isShowReportView: Bool = false
    
    var body: some View {
        ZStack {
            Color.secondaryBackgroundColor.ignoresSafeArea()
            
            VStack(alignment: .center, spacing: .zero) {
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Block Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundStyle(.red)
                                Text("ユーザーをブロックする")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .padding(.horizontal, 8)
                            
                            VStack(alignment: .leading, spacing: 20) {
                                Text("お互いの投稿やプロフィールが表示されなくなり、メッセージの送受信もできなくなります。ブロックしたことは相手には通知されません。")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.gray)
                                    .lineSpacing(4)
                                
                                Button(action: {
                                    self.isShowBlockAlert.toggle()
                                }) {
                                    Text("ブロックする")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color.red)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(20)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        
                        // Report Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "exclamationmark.bubble.fill")
                                    .foregroundStyle(.orange)
                                Text("運営に通報する")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .padding(.horizontal, 8)
                            
                            VStack(alignment: .leading, spacing: 20) {
                                Text("利用規約に違反する行為（迷惑行為、誹謗中傷など）を確認した場合、報告してください。運営チームが内容を確認し、対処いたします。")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.gray)
                                    .lineSpacing(4)
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        self.isShowReportView.toggle()
                                    }
                                }) {
                                    Text("通報する")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.red)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color.red.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(20)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .padding(20)
                }
            }
            .alert("確認", isPresented: $isShowBlockAlert) {
                Button("キャンセル", role: .cancel) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.isShowBlockAlert.toggle()
                    }
                }
                Button("ブロック", role: .destructive) {
                    self.chatRoomViewModel.blockingUser { roomId in
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.chatRoomRootViewModel.pop(1)
                            self.homeRootViewModel.pop(1)
                            self.chatViewModel.removeChatRoom(roomId: roomId)
                        }
                    }
                }
            } message: {
                Text("お相手のユーザーをブロックしますか？")
            }
        }
        .fullScreenCover(isPresented: $isShowReportView) {
            ReportView(isShowWindow: $isShowReportView)
                .environmentObject(chatRoomViewModel)
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center) {
            Text("通報とブロック")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black.opacity(0.85))
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowWindow.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}

fileprivate struct NotificationView: View {
    @EnvironmentObject private var chatRoomViewModel: ChatRoomViewModel
    
    @Binding var isShowWindow: Bool
    
    var body: some View {
        ZStack {
            Color.secondaryBackgroundColor.ignoresSafeArea()
            
            VStack(alignment: .center, spacing: .zero) {
                headerView
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("メッセージ通知")
                                    .font(.system(size: 17, weight: .bold))
                                Text("新着メッセージの通知を受け取る")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                            Toggle("", isOn: $chatRoomViewModel.isOnMessageNotification)
                                .labelsHidden()
                                .tint(Color.mainColor)
                        }
                        
                        Divider()
                        
                        Text("オフにすると、アプリを開くまで新着メッセージの通知が表示されなくなります。")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.gray.opacity(0.8))
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(20)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onDisappear {
            self.chatRoomViewModel.updateMessageNotification()
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center, spacing: .zero) {
            Text("通知設定")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black.opacity(0.85))
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowWindow.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}

fileprivate struct MediaView: View {
    @EnvironmentObject private var chatRoomViewModel: ChatRoomViewModel
    
    @Binding var isShowWindow: Bool
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 2), count: 3)
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(alignment: .center, spacing: .zero) {
                headerView
                
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        if chatRoomViewModel.mediaImages.isEmpty {
                            VStack(spacing: 12) {
                                Spacer()
                                    .frame(height: 100)
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.gray.opacity(0.3))
                                Text("メディアがありません")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.gray.opacity(0.5))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(chatRoomViewModel.mediaImages) { message in
                                    GeometryReader { geometry in
                                        let sideLength = geometry.size.width
                                        ZStack {
                                            WebImage(url: URL(string: message.context)) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } placeholder: {
                                                Rectangle()
                                                    .foregroundStyle(.gray.opacity(0.1))
                                                    .skelton(isActive: true)
                                            }
                                        }
                                        .frame(width: sideLength, height: sideLength)
                                        .clipped()
                                        .overlay(alignment: .bottomTrailing) {
                                            Text(dateFormat(date: message.createdAt))
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.black.opacity(0.4))
                                                .clipShape(Capsule())
                                                .padding(4)
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center) {
            Text("写真と動画")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black.opacity(0.85))
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowWindow.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
    
    private func dateFormat(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d"
        return dateFormatter.string(from: date)
    }
}

fileprivate struct ReportView: View {
    @EnvironmentObject private var chatRoomViewModel: ChatRoomViewModel
    @Binding var isShowWindow: Bool
    
    @State private var selectedReason: String? = nil
    @State private var reportDetail: String = ""
    
    @FocusState private var focus: Bool
    
    private let reportReasons = [
        "不適切なプロフィール内容",
        "不快なメッセージ・迷惑行為",
        "詐欺・勧誘・スパム",
        "出会い系以外の目的",
        "その他"
    ]
    
    var body: some View {
        ZStack {
            Color.secondaryBackgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("通報する理由を選んでください")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black.opacity(0.7))
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 0) {
                                ForEach(0..<reportReasons.count, id: \.self) { index in
                                    let reason = reportReasons[index]
                                    Button(action: {
                                        selectedReason = reason
                                    }) {
                                        HStack {
                                            Text(reason)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(.black.opacity(0.8))
                                            Spacer()
                                            if selectedReason == reason {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(Color.selectedColor)
                                            }
                                        }
                                        .padding(.vertical, 16)
                                        .padding(.horizontal, 20)
                                        .background(Color.white)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if index < reportReasons.count - 1 {
                                        Divider()
                                            .padding(.leading, 20)
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("具体的な理由（任意）")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black.opacity(0.7))
                                .padding(.horizontal, 4)
                            
                            ZStack(alignment: .topLeading) {
                                if reportDetail.isEmpty {
                                    Text("通報内容を具体的に入力してください")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.gray.opacity(0.5))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                
                                TextEditor(text: $reportDetail)
                                    .focused($focus)
                                    .font(.system(size: 14))
                                    .frame(height: 120)
                                    .scrollContentBackground(.hidden)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        
                        Button(action: {
                            if let reason = selectedReason {
                                self.chatRoomViewModel.sendReport(type: reason, report: reportDetail)
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.isShowWindow.toggle()
                                }
                            }
                        }) {
                            Text("送信する")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(selectedReason == nil ? Color.gray.opacity(0.3) : Color.mainColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(selectedReason == nil)
                        .padding(.top, 8)
                        
                        Text("通報内容は運営チームによって慎重に確認されます。虚偽の通報を行った場合、利用制限の対象となる可能性があります。")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray.opacity(0.7))
                            .lineSpacing(4)
                            .padding(.horizontal, 4)
                    }
                    .padding(24)
                }
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.focus = false
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isShowWindow.toggle()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("通報")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black.opacity(0.85))
            
            Spacer()
            
            // For symmetry
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .bold))
                .opacity(0)
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}
