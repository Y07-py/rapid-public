//
//  ProfileSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/17.
//

import Foundation
import SwiftUI

struct ProfileSettingView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    @EnvironmentObject private var mainRootViewModel: RootViewModel<MainRoot>
    @EnvironmentObject private var notificationViewModel: NotificationViewModel
    
    // Show flag of section view.
    @State private var isShowSubscriptionView: Bool = false
    @State private var isShowPointPurchaseHistoryView: Bool = false
    @State private var isShowExternalAccountSettingView: Bool = false
    @State private var isShowIdentificationView: Bool = false
    @State private var isShowCommunityGuidelineView: Bool = false
    @State private var isShowLegalTermsView: Bool = false
    @State private var isShowCommercialDisclosureView: Bool = false
    @State private var isShowSupportHelpView: Bool = false
    
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
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 25) {
                        // Account section
                        settingSection(title: "アカウント") {
                            VStack(spacing: 0) {
                                if profileViewModel.user?.user.sex == "man" {
                                    settingRow(icon: "creditcard.fill", label: "サブスクリプションの管理", action: { isShowSubscriptionView.toggle() })
                                    settingDivider
                                }
                                settingRow(icon: "clock.arrow.2.circlepath", label: "ポイント購入履歴の確認", action: { isShowPointPurchaseHistoryView.toggle() })
                                settingDivider
//                                settingRow(icon: "person.badge.key.fill", label: "外部アカウントの設定", action: { isShowExternalAccountSettingView.toggle() })
//                                settingDivider
                                settingRow(icon: "checkmark.seal.fill", label: "本人確認", action: { isShowIdentificationView.toggle() }) {
                                    if profileViewModel.isIdentityVerified {
                                        Text("完了")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.selectedColor)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        
                        // Notification section
                        settingSection(title: "通知設定") {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("プッシュ通知")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.gray.opacity(0.6))
                                
                                notificationToggle(title: "マッチング成立時", isOn: $notificationViewModel.isPushMatching)
                                settingDivider
                                notificationToggle(title: "メッセージ受信時", isOn: $notificationViewModel.isPushMessage)
                                
                                Text("メール通知")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.gray.opacity(0.6))
                                    .padding(.top, 10)
                                
                                notificationToggle(title: "運営からのお知らせ", isOn: $notificationViewModel.isEmailNews)
                            }
                            .onChange(of: notificationViewModel.isPushMatching) { notificationViewModel.updateSettings() }
                            .onChange(of: notificationViewModel.isPushMessage) { notificationViewModel.updateSettings() }
                            .onChange(of: notificationViewModel.isEmailNews) { notificationViewModel.updateSettings() }
                        }
                        
                        // Support and Legal section
                        settingSection(title: "サポート・法的情報") {
                            VStack(spacing: 0) {
                                settingRow(icon: "questionmark.circle.fill", label: "お問い合わせ・ヘルプ", action: { isShowSupportHelpView.toggle() })
                                settingDivider
                                settingRow(icon: "doc.text.fill", label: "利用規約 / プライバシーポリシー", action: { isShowLegalTermsView.toggle() })
                                settingDivider
                                settingRow(icon: "shield.fill", label: "特定商取引法に基づく表記", action: { isShowCommercialDisclosureView.toggle() })
                                settingDivider
                                settingRow(icon: "person.2.fill", label: "コミュニティガイドライン", action: { isShowCommunityGuidelineView.toggle() })
                                settingDivider
                                
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .frame(width: 32, height: 32)
                                        .foregroundStyle(.gray.opacity(0.5))
                                    Text("アプリバージョン")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.black.opacity(0.7))
                                    Spacer()
                                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.gray)
                                }
                                .padding(.vertical, 12)
                            }
                        }
                        
                        // Danger section
                        Button(action: {
                            Task {
                                await SupabaseManager.shared.signOut()
                                mainRootViewModel.push(.login)
                            }
                        }) {
                            HStack {
                                Spacer()
                                Text("ログアウト")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.red)
                                Spacer()
                            }
                            .padding(18)
                            .background(Color.secondaryBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 50)
                }
            }
        }
        .fullScreenCover(isPresented: $isShowSubscriptionView) {
            ProfileSettingSubscriptionPurchaseView(isShowWindow: $isShowSubscriptionView)
        }
        .fullScreenCover(isPresented: $isShowPointPurchaseHistoryView) {
            ProfileSettingPointPurchaseHistoryView(isShowWindow: $isShowPointPurchaseHistoryView)
                .environmentObject(profileViewModel)
        }
        .fullScreenCover(isPresented: $isShowExternalAccountSettingView) {
            ProfileExternalAccountSettingView(isShowWindow: $isShowExternalAccountSettingView)
                .environmentObject(profileViewModel)
        }
        .fullScreenCover(isPresented: $isShowIdentificationView) {
            ProfileIdentityVeriticationView(isShowWindow: $isShowIdentificationView)
                .environmentObject(profileViewModel)
        }
        .fullScreenCover(isPresented: $isShowCommunityGuidelineView) {
            CommunityGuidelineView(isShowWindow: $isShowCommunityGuidelineView)
        }
        .fullScreenCover(isPresented: $isShowLegalTermsView) {
            LegalTermsView(isShowWindow: $isShowLegalTermsView)
        }
        .fullScreenCover(isPresented: $isShowCommercialDisclosureView) {
            CommercialDisclosureView(isShowWindow: $isShowCommercialDisclosureView)
        }
        .fullScreenCover(isPresented: $isShowSupportHelpView) {
            SupportHelpView(isShowWindow: $isShowSupportHelpView)
                .environmentObject(profileViewModel)
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.homeRootViewModel.pop(1)
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color.secondaryBackgroundColor)
                    .clipShape(Circle())
            }
            
            Text("設定")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
                .padding(.leading, 10)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20) // Adjusted for notch
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private func settingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black.opacity(0.55))
                .padding(.leading, 5)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color.secondaryBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
        }
    }
    
    @ViewBuilder
    private func settingRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        settingRow(icon: icon, label: label, action: action) { EmptyView() }
    }
    
    @ViewBuilder
    private func settingRow<Content: View>(icon: String, label: String, action: @escaping () -> Void, @ViewBuilder trailing: () -> Content) -> some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 32, height: 32)
                    .background(Color.selectedColor.opacity(0.1))
                    .foregroundStyle(Color.selectedColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.7))
                
                Spacer()
                
                trailing()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.3))
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func notificationToggle(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black.opacity(0.7))
        }
        .tint(Color.selectedColor)
        .padding(.vertical, 4)
    }
    
    private var settingDivider: some View {
        Divider().padding(.leading, 47).opacity(0.5)
    }
}
