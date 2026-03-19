//
//  MaintenanceView.swift
//  Rapid
//
//  Created by antigravity on 2026/03/13.
//

import SwiftUI

struct MaintenanceView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "gearshape.2.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.gray)
                
                Text("ただいまメンテナンス中です")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Text("サービス向上のため、サーバーのメンテナンスを行っております。\n終了までしばらくお待ちください。")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button(action: {
                    NotificationCenter.default.post(name: .retryMaintenanceCheckNotification, object: nil)
                }) {
                    Text("再試行")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 48)
                        .background(Color.blue)
                        .cornerRadius(24)
                }
                .padding(.top, 8)
            }
        }
    }
}

extension Notification.Name {
    static let retryMaintenanceCheckNotification = Notification.Name("retryMaintenanceCheckNotification")
}

#Preview {
    MaintenanceView()
}
