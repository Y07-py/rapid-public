//
//  ProfileSettingPointPurchaseHistoryView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/23.
//

import Foundation
import SwiftUI
import RevenueCat

struct ProfileSettingPointPurchaseHistoryView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @Binding var isShowWindow: Bool
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            // Decorative background glow
            VStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -150, y: -100)
                Spacer()
                Circle()
                    .fill(Color.mainColor.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: 150, y: 100)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerBar
                
                if profileViewModel.purchaseHistory.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(profileViewModel.purchaseHistory, id: \.transactionIdentifier) { transaction in
                                purchaseRow(transaction: transaction)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .onAppear {
            profileViewModel.fetchPurchaseHistory()
        }
    }
    
    private var headerBar: some View {
        HStack {
            Button(action: { isShowWindow = false }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(Color.secondaryBackgroundColor)
                    .clipShape(Circle())
            }
            
            Text("ポイント購入履歴")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
                .padding(.leading, 10)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "basket.fill")
                .font(.system(size: 60))
                .foregroundStyle(.gray.opacity(0.2))
            
            Text("購入履歴はまだありません")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.gray.opacity(0.5))
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func purchaseRow(transaction: NonSubscriptionTransaction) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(getProductName(for: transaction.productIdentifier))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text(formattedDate(transaction.purchaseDate))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Text("完了")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.mainColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.mainColor.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
    }
    
    private func getProductName(for id: String) -> String {
        switch id {
        case "rapid.60_point": return "60pt チャージ"
        case "rapid.120_point": return "120pt チャージ"
        case "rapid.180_point": return "180pt チャージ"
        case "rapid.240_point": return "240pt チャージ"
        case "rapid.300_point": return "300pt チャージ"
        case "rapid_premium_one_month_v1": return "プレミアムプラン"
        default: return "アイテム購入"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
