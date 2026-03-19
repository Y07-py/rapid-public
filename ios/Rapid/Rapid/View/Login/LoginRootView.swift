//
//  LoginRootView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/09.
//

import Foundation
import SwiftUI

enum LoginRoot: Equatable {
    case login
    case verify
    case setting
}

struct LoginRootView: View {
    @StateObject private var loginRootViewModel: RootViewModel<LoginRoot> = .init(root: .login)
    @StateObject private var loginViewModel = LoginViewModel()
    
    @State private var loginErrorHappened: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        ZStack {
            RootViewController(rootViewModel: loginRootViewModel) { root in
                switch root {
                case .login: LoginView()
                        .environmentObject(loginViewModel)
                        .environmentObject(loginRootViewModel)
                case .verify: LoginVerifyView()
                        .environmentObject(loginViewModel)
                        .environmentObject(loginRootViewModel)
                case .setting: ProfileLoginSettingRootView()
                        .environmentObject(loginViewModel)
                        .environmentObject(loginRootViewModel)
                }
            }
            .navigationBarBackButtonHidden(true)
            .ignoresSafeArea()
            .onReceive(NotificationCenter.default.publisher(for: .loginErrorNotification)) { notification in
                if let errorDescription = notification.userInfo?["message"] as? String {
                    loginErrorHappened.toggle()
                    errorMessage = errorDescription
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .pushRootViewNotification, object: nil), perform: { notification in
                if let loginRoot = notification.userInfo?["root"] as? LoginRoot {
                    self.loginRootViewModel.push(loginRoot)
                }
            })
            .alert(isPresented: $loginErrorHappened) {
                Alert(
                    title: Text("ログインエラー"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            
            if loginViewModel.waitMode {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("認証中...")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(40)
                    .background {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.black.opacity(0.6))
                            .background(.ultraThinMaterial)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut, value: loginViewModel.waitMode)
    }
}
