//
//  ProfileExternalAccountSettingView.swift
//  Rapid
//
//  Created by Antigravity on 2026/02/23.
//

import SwiftUI

struct ProfileExternalAccountSettingView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @Binding var isShowWindow: Bool
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        titleSection
                        
                        accountListSection
                        
                        descriptionSection
                    }
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isShowWindow = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.black.opacity(0.8))
            }
            .padding(20)
            Spacer()
        }
    }
    
    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("外部アカウント連携")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
            
            Text("他のアカウントと連携して、ログインをより便利に。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private var accountListSection: some View {
        VStack(spacing: 16) {
            accountRow(
                iconName: "Apple_Brand_icon",
                title: "Apple",
                isLinked: profileViewModel.isAppleLinked,
                action: {
                    // TODO: Apple link/unlink action
                }
            )
            
            accountRow(
                iconName: "Google_Brand_icon",
                title: "Google",
                isLinked: profileViewModel.isGoogleLinked,
                action: {
                    // TODO: Google link/unlink action
                }
            )
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func accountRow(iconName: String, title: String, isLinked: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text(isLinked ? "連携済み" : "未連携")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isLinked ? Color.mainColor : .gray)
            }
            
            Spacer()
            
            Button(action: action) {
                Text(isLinked ? "解除する" : "連携する")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isLinked ? .gray : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isLinked ? Color.gray.opacity(0.1) : Color.mainColor)
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .baseShadow()
    }
    
    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("アカウント連携について")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black.opacity(0.7))
            
            Text("外部アカウントを連携しておくと、機種変更やアプリの再インストール時にスムーズにアカウントを引き継ぐことができます。")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.gray)
                .lineSpacing(4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color.mainColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
    }
}

#Preview {
    ProfileExternalAccountSettingView(isShowWindow: .constant(true))
        .environmentObject(ProfileViewModel())
}
