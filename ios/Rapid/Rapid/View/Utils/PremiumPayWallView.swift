//
//  PremiumPayWallView.swift
//  Rapid
//
//  Created by Antigravity on 2026/02/23.
//

import SwiftUI
import RevenueCat

struct PremiumPayWallView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @Binding var isPresented: Bool
    
    @State private var currentOffering: Offering?
    @State private var premiumPackages: [Package] = []
    @State private var isProcessing: Bool = false
    @State private var showSuccess: Bool = false
    
    // Feature Categories defined in the request
    private let categories: [FeatureCategory] = [
        .init(
            title: "出会いを加速させる",
            subtitle: "効率",
            icon: "bolt.fill",
            items: [
                "タイムラインでの優先表示",
                "いいねの優先表示"
            ]
        ),
        .init(
            title: "理想の場所で繋がる",
            subtitle: "ロケーション",
            icon: "mappin.and.ellipse",
            items: [
                "ロケーション検索の無償枠増加",
                "ピンポイント検索"
            ]
        ),
        .init(
            title: "確実な関係を作る",
            subtitle: "コミュニケーション",
            icon: "sparkles",
            items: [
                "メッセージ送信の無制限化",
                "メッセージ付きいいねの解放",
                "ボイスチャット機能の利用"
            ]
        ),
        .init(
            title: "チャンスを広げる",
            subtitle: "上限緩和",
            icon: "square.2.layers.3d.top.filled",
            items: [
                "いいね上限数の増加"
            ]
        )
    ]
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            if showSuccess {
                successView
            } else {
                mainContentView
            }
            
            if isProcessing {
                processingOverlay
            }
        }
        .onAppear {
            fetchOfferings()
        }
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            headerView
            
            ScrollView {
                VStack(spacing: 32) {
                    titleSection
                    
                    featureGrid
                    
                    priceAndActionSection
                }
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.6))
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var titleSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.mainColor)
                    .frame(width: 64, height: 64)
                    .baseShadow()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            
            Text("理想の出会いを、もっと自由に。")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.black.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
    }
    
    private var featureGrid: some View {
        VStack(spacing: 16) {
            ForEach(categories) { category in
                HStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .frame(width: 54, height: 54)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: category.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(Color.mainColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(category.subtitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black.opacity(0.8))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(category.items, id: \.self) { item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.mainColor.opacity(0.1))
                                        .frame(width: 16, height: 16)
                                        .overlay {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(Color.mainColor)
                                        }
                                    
                                    Text(item)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .baseShadow()
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var priceAndActionSection: some View {
        VStack(spacing: 24) {
            if let package = premiumPackages.first {
                VStack(spacing: 16) {
                    HStack(alignment: .bottom, spacing: 4) {
                        Text(package.localizedPriceString)
                            .font(.system(size: 40, weight: .black))
                            .foregroundStyle(Color.mainColor)
                        
                        Text(package.packageType == .monthly ? "/月" : "")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.gray)
                            .padding(.bottom, 8)
                    }
                    
                    Button(action: { 
                        purchase(package: package)
                    }) {
                        Text("購読を開始する")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.subscriptionColor)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .baseShadow()
                    }
                    .disabled(isProcessing)
                    .padding(.horizontal, 20)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("プランを読み込み中...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.gray)
                }
                .padding(.vertical, 20)
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 12))
                    Text("いつでもキャンセル可能 • 安心の決済システム")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.gray)
                
                Button(action: {
                    isProcessing = true
                    profileViewModel.restorePurchases { success in
                        isProcessing = false
                        if success {
                            withAnimation { showSuccess = true }
                        }
                    }
                }) {
                    Text("以前の購入を復元")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.mainColor)
                }
                .disabled(isProcessing)
            }
        }
    }
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("決済を処理しています...")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
    
    private var successView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.green)
            }
            
            VStack(spacing: 12) {
                Text("購読完了！")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text("プレミアム機能がすべて解放されました。")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: { isPresented = false }) {
                Text("閉じる")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .padding(20)
    }
    
    private func fetchOfferings() {
        Purchases.shared.getOfferings { offerings, error in
            if let error = error {
                print("[DEBUG] Error fetching offerings: \(error.localizedDescription)")
                return
            }
            
            // Hardcoded search for the specific premium package
            if let allOfferings = offerings?.all.values {
                for offering in allOfferings {
                    if let pkg = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == "rapid_premium_one_month_v1" }) {
                        self.premiumPackages = [pkg]
                        break
                    }
                }
            }
            
            if let offering = offerings?.current {
                self.currentOffering = offering
            }
        }
    }
    
    private func purchase(package: Package) {
        isProcessing = true
        Purchases.shared.purchase(package: package) { transaction, customerInfo, error, userCancelled in
            isProcessing = false
            if let customerInfo = customerInfo, !userCancelled {
                if customerInfo.entitlements["Rapid Premium"]?.isActive == true {
                    withAnimation {
                        showSuccess = true
                    }
                    profileViewModel.fetchSubscriptionStatus()
                }
            }
        }
    }
}

// Helper models for feature visualization
struct FeatureCategory: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let items: [String]
}

#Preview {
    PremiumPayWallView(isPresented: .constant(true))
        .environmentObject(ProfileViewModel())
}
