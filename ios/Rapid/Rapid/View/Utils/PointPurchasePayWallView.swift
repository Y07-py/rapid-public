//
//  PointPurchasePayWallView.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/02.
//

import SwiftUI
import RevenueCat

struct PointPackage: Identifiable {
    let id: String
    let points: Int
    let price: String
    let discount: String?
    let package: Package
}

struct PointPurchasePayWallView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @Binding var isPresented: Bool
    
    @State private var availablePlans: [PointPackage] = []
    @State private var selectedPlanId: String? = nil
    @State private var isProcessing: Bool = false
    @State private var showSuccess: Bool = false
    @State private var currentOffering: Offering?
    
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
                    
                    planListSection
                    
                    purchaseButtonSection
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
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .baseShadow()
                
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.orange)
            }
            
            Text("ポイントをチャージ")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.black.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Text("スポットの検索やボイスチャット機能に\nポイントを利用できます。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 20)
    }
    
    private var planListSection: some View {
        VStack(spacing: 12) {
            if availablePlans.isEmpty && !isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("プランを読み込み中...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.gray)
                }
                .padding(.vertical, 40)
            } else {
                ForEach(availablePlans) { plan in
                    planRow(plan: plan)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func planRow(plan: PointPackage) -> some View {
        let isSelected = selectedPlanId == plan.id
        
        Button(action: {
            withAnimation(.snappy) {
                selectedPlanId = plan.id
            }
        }) {
            HStack {
                // Points
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(plan.points)")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(isSelected ? Color.subscriptionColor : .black.opacity(0.8))
                    Text("pt")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isSelected ? Color.subscriptionColor.opacity(0.8) : .gray)
                        .padding(.bottom, 3)
                }
                
                Spacer()
                
                // Discount badge
                if let discount = plan.discount {
                    Text(discount)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                
                // Price
                Text(plan.price)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? Color.subscriptionColor : .black.opacity(0.8))
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(16)
            .background(isSelected ? Color.subscriptionColor.opacity(0.05) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.subscriptionColor : Color.gray.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? Color.subscriptionColor.opacity(0.2) : .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private var purchaseButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                guard let planId = selectedPlanId,
                      let plan = availablePlans.first(where: { $0.id == planId }) else { return }
                
                purchase(package: plan.package, points: plan.points)
            }) {
                Text("購入する")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(selectedPlanId == nil ? Color.gray : Color.subscriptionColor)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .baseShadow()
            }
            .disabled(selectedPlanId == nil || isProcessing)
            
            Text("購入後のキャンセル・返金はできません。\nお支払いはApple IDに請求されます。")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 20)
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
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.orange)
            }
            
            VStack(spacing: 12) {
                Text("チャージ完了！")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.black.opacity(0.8))
                
                if let planId = selectedPlanId,
                   let plan = availablePlans.first(where: { $0.id == planId }) {
                    Text("\(plan.points)ポイントを獲得しました。\nさっそく機能を使ってみましょう！")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
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
    
    // MARK: - RevenueCat Integration (Placeholder)
    
    private func fetchOfferings() {
        Purchases.shared.getOfferings { offerings, error in
            if let error = error {
                print("[DEBUG] Error fetching offerings: \(error.localizedDescription)")
                return
            }
            
            let targetIdentifiers = [
                "rapid.60_point",
                "rapid.120_point",
                "rapid.180_point",
                "rapid.240_point",
                "rapid.300_point"
            ]
            let pointsMap: [String: Int] = [
                "rapid.60_point": 60,
                "rapid.120_point": 120,
                "rapid.180_point": 180,
                "rapid.240_point": 240,
                "rapid.300_point": 300
            ]
            
            var foundPlans: [PointPackage] = []
            
            // Search across all offerings for the exact target identifiers
            if let allOfferings = offerings?.all.values {
                for identifier in targetIdentifiers {
                    var foundForThisId = false
                    for offering in allOfferings {
                        if let pkg = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == identifier }) {
                            foundPlans.append(.init(
                                id: identifier,
                                points: pointsMap[identifier] ?? 0,
                                price: pkg.localizedPriceString,
                                discount: nil,
                                package: pkg
                            ))
                            foundForThisId = true
                            break
                        }
                    }
                    if !foundForThisId {
                        print("[DEBUG] Warning: Could not find package for identifier: \(identifier)")
                    }
                }
            }
            
            self.availablePlans = foundPlans
            
            if let offering = offerings?.current {
                self.currentOffering = offering
            }
            
            // Auto-select the first one if none selected
            if self.selectedPlanId == nil, let first = foundPlans.first {
                self.selectedPlanId = first.id
            }
        }
    }
    
    private func purchase(package: Package, points: Int) {
        isProcessing = true
        Purchases.shared.purchase(package: package) { transaction, customerInfo, error, userCancelled in
            isProcessing = false
            if let _ = customerInfo, !userCancelled && error == nil {
                Task { @MainActor in
                    // Add points to database and UI
                    await profileViewModel.addPoints(points)
                    withAnimation {
                        showSuccess = true
                    }
                }
            }
        }
    }
}

#Preview {
    PointPurchasePayWallView(isPresented: .constant(true))
        .environmentObject(ProfileViewModel())
}
