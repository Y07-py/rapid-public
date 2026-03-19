//
//  ProfileSubscriptionPurchaseView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/23.
//

import Foundation
import SwiftUI

struct ProfileSettingSubscriptionPurchaseView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @Binding var isShowWindow: Bool
    @State private var isShowPremiumPayWall: Bool = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                headerView
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        titleSection
                        
                        subscriptionStatusSection
                        
                        purchaseHistorySection
                    }
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .fullScreenCover(isPresented: $isShowPremiumPayWall) {
            PremiumPayWallView(isPresented: $isShowPremiumPayWall)
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center) {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowWindow.toggle()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.black.opacity(0.8))
            }
            .padding([.top, .leading], 20)
            Spacer()
        }
    }
    
    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("サブスクリプションの管理")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
            
            Text("現在のプラン状況の確認と管理ができます。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private var subscriptionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("現在のプラン")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.gray)
            
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profileViewModel.currentPlanName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.black.opacity(0.8))
                        
                        Text(profileViewModel.isPremium ? "プレミアムな機能がすべて利用可能です" : "基本機能のみ利用可能です")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.gray)
                    }
                    
                    Spacer()
                    
                    statusBadge
                }
                
                if profileViewModel.isPremium {
                    Divider()
                        .background(Color.gray.opacity(0.2))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: profileViewModel.membershipStatus == "解約予約済み" ? "calendar.badge.exclamationmark" : "calendar.badge.clock")
                                .foregroundStyle(profileViewModel.membershipStatus == "解約予約済み" ? .orange : Color.mainColor)
                            
                            Text(profileViewModel.membershipStatus == "解約予約済み" ? "有効期限" : "次回更新日")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black.opacity(0.7))
                        }
                        
                        if let expirationDate = profileViewModel.expirationDate {
                            if let price = profileViewModel.nextRenewalPrice, profileViewModel.membershipStatus == "有効" {
                                Text("次回は \(dateFormatter.string(from: expirationDate)) に \(price) が決済されます")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.black.opacity(0.8))
                            } else {
                                Text(dateFormatter.string(from: expirationDate))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.black.opacity(0.8))
                            }
                        }
                    }
                } else {
                    Divider()
                        .background(Color.gray.opacity(0.2))
                    Button(action: {
                        self.isShowPremiumPayWall.toggle()
                    }) {
                        HStack(alignment: .center, spacing: 10) {
                            Circle()
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.gray.opacity(0.1))
                                .overlay {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.black.opacity(0.6))
                                }
                            Text("プランのアップグレード")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black.opacity(0.8))
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(Color.secondaryBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .baseShadow()
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        Text(profileViewModel.membershipStatus)
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusBadgeColor.opacity(0.1))
            .foregroundStyle(statusBadgeColor)
            .clipShape(Capsule())
    }
    
    private var statusBadgeColor: Color {
        switch profileViewModel.membershipStatus {
        case "有効": return Color.mainColor
        case "解約予約済み": return .orange
        case "期限切れ": return .gray
        default: return .gray
        }
    }
    
    @ViewBuilder
    private var purchaseHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("お支払い")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.gray)
            
            Button(action: {
                // TODO: Show purchase history
            }) {
                HStack(spacing: 15) {
                    Circle()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(Color.gray.opacity(0.1))
                        .overlay {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundStyle(.black.opacity(0.6))
                        }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("購入履歴")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black.opacity(0.8))
                        
                        Text("過去の決済内容や領収書を確認")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.gray.opacity(0.5))
                }
                .padding(20)
                .background(Color.secondaryBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .baseShadow()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }
}
