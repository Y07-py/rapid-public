//
//  LoginView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/09.
//

import Foundation
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var loginRootViewModel: RootViewModel<LoginRoot>
    @EnvironmentObject private var loginViewModel: LoginViewModel
    
    @FocusState private var isFocused: Bool
    @Namespace private var namespace
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            // Decorative background glows
            VStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.1))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: -150, y: -100)
                Spacer()
                Circle()
                    .fill(Color.selectedColor.opacity(0.08))
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .offset(x: 150, y: 100)
            }
            .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .center, spacing: 40) {
                    
                    // Header Section
                    headerSection
                    
                    // Input Card Section
                    VStack(spacing: 24) {
                        tabSelector
                        
                        if loginViewModel.selectedLoginType == .email {
                            emailInputField
                        } else {
                            phoneInputField
                        }
                        
                        loginActionButton
                    }
                    .padding(24)
                    .background {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.white.opacity(0.7))
                            .background(.ultraThinMaterial)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    }
                    .padding(.horizontal, 24)
                    
                    // Divider
                    HStack {
                        VStack { Divider().background(Color.black.opacity(0.1)) }
                        Text("または")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.gray.opacity(0.6))
                            .padding(.horizontal, 8)
                        VStack { Divider().background(Color.black.opacity(0.1)) }
                    }
                    .padding(.horizontal, 40)
                    
                    // Social Login Buttons
                    VStack(alignment: .center, spacing: 14) {
                        loginButton("Googleでログイン", icon: "Google_Brand_icon") {
                            Task {
                                loginViewModel.selectedLoginType = .google
                                await loginViewModel.signIn()
                            }
                        }
                        loginButton("Appleでログイン", icon: "Apple_Brand_icon") {
                            Task {
                                loginViewModel.selectedLoginType = .apple
                                await loginViewModel.signIn()
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.top, 60)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard)
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Rapid")
                .font(.system(size: 48, weight: .black))
                .kerning(-2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.mainColor, .mainColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("今、ここから始まる出会い")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black.opacity(0.6))
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    loginViewModel.selectedLoginType = .email
                }
            }) {
                Text("メール")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(loginViewModel.selectedLoginType == .email ? .white : .black.opacity(0.5))
                    .background {
                        if loginViewModel.selectedLoginType == .email {
                            Capsule()
                                .fill(Color.subFontColor)
                                .matchedGeometryEffect(id: "tabSelector", in: namespace)
                        }
                    }
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    loginViewModel.selectedLoginType = .phoneNumber
                }
            }) {
                Text("電話番号")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(loginViewModel.selectedLoginType == .phoneNumber ? .white : .black.opacity(0.5))
                    .background {
                        if loginViewModel.selectedLoginType == .phoneNumber {
                            Capsule()
                                .fill(Color.subFontColor)
                                .matchedGeometryEffect(id: "tabSelector", in: namespace)
                        }
                    }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.04))
        .clipShape(Capsule())
    }
    
    private var emailInputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("メールアドレス")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black.opacity(0.4))
                .padding(.leading, 4)
            
            TextField("example@mail.com", text: $loginViewModel.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .focused($isFocused)
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                }
        }
    }
    
    private var phoneInputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("電話番号")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black.opacity(0.4))
                .padding(.leading, 4)
            
            HStack(spacing: 12) {
                Picker("", selection: $loginViewModel.selectedCountry) {
                    ForEach(loginViewModel.countries) { country in
                        Text("\(country.flag) +\(country.code)")
                            .tag(country)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100, height: 50)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                }
                
                TextField("09012345678", text: $loginViewModel.phoneNumber)
                    .keyboardType(.phonePad)
                    .focused($isFocused)
                    .padding()
                    .frame(height: 50)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    }
                    .onChange(of: loginViewModel.phoneNumber) { _, new in
                        loginViewModel.formatForCountry(new)
                    }
            }
        }
    }
    
    private var loginActionButton: some View {
        Button(action: {
            Task {
                await loginViewModel.signIn()
                loginRootViewModel.push(.verify)
            }
        }) {
            Text("次へ進む")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.subFontColor, Color.subFontColor.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color.subFontColor.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func loginButton(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 30)
                
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            }
            // Shadow removed as requested
        }
        .padding(.horizontal, 24)
    }
}

