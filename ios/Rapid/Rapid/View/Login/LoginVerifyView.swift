//
//  LoginVerifyView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/09.
//

import Foundation
import SwiftUI

enum OTPField: Int, CaseIterable {
    case first = 1
    case second = 2
    case third = 3
    case fourth = 4
    case fifth = 5
    case sixth = 6
}

struct LoginVerifyView: View {
    @EnvironmentObject private var loginRootViewModel: RootViewModel<LoginRoot>
    @EnvironmentObject private var loginViewModel: LoginViewModel
    @FocusState private var otpField: OTPField?
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            // Decorative background glows (Matching LoginView)
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
            
            VStack(spacing: 0) {
                // Header (Back Nav)
                headerView
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        // Instructional Text
                        VStack(spacing: 12) {
                            Text("認証コードを入力")
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(Color.subFontColor)
                            
                            VStack(spacing: 4) {
                                Text("ご登録いただいたアドレス宛に")
                                Text("6桁の認証コードを送信しました。")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.black.opacity(0.5))
                            .multilineTextAlignment(.center)
                            
                            if !loginViewModel.email.isEmpty && loginViewModel.selectedLoginType == .email {
                                Text(loginViewModel.email)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.mainColor)
                                    .padding(.top, 4)
                            } else if !loginViewModel.phoneNumber.isEmpty && loginViewModel.selectedLoginType == .phoneNumber {
                                Text(loginViewModel.phoneNumber)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.mainColor)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.top, 20)
                        
                        // OTP Input Card
                        VStack(spacing: 32) {
                            HStack(spacing: 10) {
                                ForEach(OTPField.allCases, id: \.self) { field in
                                    OTPFieldView(selectedOtpField: $otpField, otpField: field)
                                        .environmentObject(loginViewModel)
                                }
                            }
                            .padding(.horizontal, 4)
                            
                            verifyButton
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
                        
                        // Resend Section
                        Button(action: {
                            Task {
                                await loginViewModel.signIn()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("コードが届かない場合は")
                                    .foregroundStyle(.black.opacity(0.5))
                                Text("再送信")
                                    .foregroundStyle(Color.mainColor)
                                    .fontWeight(.bold)
                            }
                            .font(.system(size: 14))
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
        }
        .onAppear {
            otpField = .first
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Button(action: {
                loginRootViewModel.pop(1)
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.subFontColor)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.5))
                    .clipShape(Circle())
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private var verifyButton: some View {
        Button(action: {
            Task {
                await loginViewModel.veryfyOtp()
            }
        }) {
            Text("認証する")
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
    }
}

struct OTPFieldView: View {
    @EnvironmentObject private var loginViewModel: LoginViewModel
    @FocusState<OTPField?>.Binding var selectedOtpField: OTPField?
    @State private var otp: String = ""
    
    let otpField: OTPField
    
    var body: some View {
        CustomTextField(
            text: $otp,
            keyboardType: .numberPad,
            alignmentType: .center,
            fontSize: 24,
            onBackspaceCallback: {
                guard let index = OTPField.allCases.firstIndex(of: selectedOtpField ?? .first) else { return }
                if otp.isEmpty && index > 0 {
                    selectedOtpField = OTPField.allCases[index - 1]
                } else {
                    otp = ""
                    loginViewModel.otp[otpField] = nil
                }
            }
        )
        .focused($selectedOtpField, equals: otpField)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(selectedOtpField == otpField ? Color.mainColor : Color.black.opacity(0.05), lineWidth: 2)
        }
        .onChange(of: otp) { oldValue, newValue in
            if newValue.count > 1 {
                otp = String(newValue.prefix(1))
            }
            
            if !otp.isEmpty {
                loginViewModel.otp[otpField] = otp.first
                let index = OTPField.allCases.firstIndex(of: otpField) ?? 0
                if index + 1 < OTPField.allCases.count {
                    selectedOtpField = OTPField.allCases[index + 1]
                }
            } else {
                loginViewModel.otp[otpField] = nil
            }
        }
    }
}
