//
//  RecruitmentConfirmView.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/01.
//

import SwiftUI
import SDWebImageSwiftUI

struct RecruitmentConfirmView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @Binding var isShowScreen: Bool
    
    @State private var editedMessage: String = ""
    @State private var isShowMessageEditor: Bool = false
    @State private var isShowingCancelAlert: Bool = false
    
    private let calendar: Calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            // Background decorations
            VStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -150, y: -100)
                Spacer()
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        // Spots Section
                        VStack(alignment: .leading, spacing: 15) {
                            sectionLabel(title: "投稿したスポット", icon: "mappin.circle.fill")
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(locationSelectViewModel.activeRecruitmentPlaces) { wrapper in
                                        activeLocationCard(wrapper)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Message Section (Editable)
                        VStack(alignment: .leading, spacing: 15) {
                            sectionLabel(title: "メッセージ", icon: "text.bubble.fill")
                            
                            Button(action: {
                                editedMessage = locationSelectViewModel.activeRecruitment?.message ?? ""
                                isShowMessageEditor = true
                            }) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(locationSelectViewModel.activeRecruitment?.message ?? "メッセージなし")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.black.opacity(0.7))
                                        .lineSpacing(4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    HStack {
                                        Spacer()
                                        Text("編集する")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.selectedColor)
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.selectedColor)
                                    }
                                }
                                .padding(20)
                                .background(Color.secondaryBackgroundColor)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                        
                        // Info Section (Read-only)
                        VStack(alignment: .leading, spacing: 15) {
                            sectionLabel(title: "その他の情報", icon: "info.circle.fill")
                            
                            VStack(spacing: 0) {
                                infoRow(icon: "calendar", label: "有効期限", value: dateFormat(locationSelectViewModel.activeRecruitment?.expiresDate))
                                infoRow(icon: "eye", label: "閲覧数", value: "\(locationSelectViewModel.activeRecruitment?.viewCount ?? 0)回", isLast: true)
                            }
                            .background(Color.secondaryBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                            .padding(.horizontal, 20)
                        }
                        
                        // Cancel Action
                        Button(action: {
                            isShowingCancelAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("投稿を取り消す")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                        }
                        .padding(.top, 10)
                        
                        Spacer(minLength: 120)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowMessageEditor) {
            messageEditorSheet
        }
        .alert("投稿の取り消し", isPresented: $isShowingCancelAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("取り消す", role: .destructive) {
                Task {
                    await locationSelectViewModel.closeActiveRecruitment()
                    withAnimation {
                        isShowScreen = false
                    }
                }
            }
        } message: {
            Text("この投稿を削除しますか？この操作は取り消せません。")
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Button(action: {
                isShowScreen = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.gray)
                    .frame(width: 40, height: 40)
                    .background(Color.secondaryBackgroundColor)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("投稿の確認")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
            
            Spacer()
            
            // Placeholder to balance
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 15)
        .background(Color.backgroundColor.opacity(0.8))
        .background(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private func sectionLabel(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.mainColor)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.gray.opacity(0.8))
        }
        .padding(.horizontal, 25)
    }
    
    @ViewBuilder
    private func activeLocationCard(_ wrapper: GooglePlacesSearchPlaceWrapper) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let photo = wrapper.place?.photos?.first {
                WebImage(url: photo.buildUrl()) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 260, height: 160)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 260, height: 160)
                        .skelton(isActive: true)
                }
                .frame(width: 260, height: 160)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 260, height: 160)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundStyle(.gray.opacity(0.3))
                    }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(wrapper.place?.displayName?.text ?? "名称未設定")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.selectedColor)
                    
                    Text(wrapper.place?.formattedAddress ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
            }
            .padding(14)
        }
        .frame(width: 260)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
    
    @ViewBuilder
    private func infoRow(icon: String, label: String, value: String, isLast: Bool = false) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.mainColor)
                .frame(width: 30)
            
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(.black.opacity(0.6))
        }
        .padding(18)
        
        if !isLast {
            Divider().padding(.leading, 60).opacity(0.3)
        }
    }
    
    @ViewBuilder
    private var messageEditorSheet: some View {
        NavigationView {
            VStack {
                TextEditor(text: $editedMessage)
                    .padding(15)
                    .background(Color.secondaryBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(20)
                
                Spacer()
            }
            .navigationTitle("メッセージの編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        isShowMessageEditor = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        Task {
                            await locationSelectViewModel.updateActiveRecruitment(messageContent: editedMessage)
                            isShowMessageEditor = false
                        }
                    }
                    .font(.system(size: 16, weight: .bold))
                }
            }
            .background(Color.backgroundColor)
        }
    }
    
    private func dateFormat(_ date: Date?) -> String {
        guard let date = date else { return "未設定" }
        return dateFormatter.string(from: date)
    }
}
