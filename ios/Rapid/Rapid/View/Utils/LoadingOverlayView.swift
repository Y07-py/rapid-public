//
//  LoadingOverlayView.swift
//  Rapid
//
//  Created by Antigravity on 2026/02/25.
//

import SwiftUI
import Lottie

struct LoadingOverlayView: View {
    let message: String
    
    init(message: String = "読み込み中...") {
        self.message = message
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent background to dim the underlying content
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                LottieView(animation: .named("Loading"))
                    .playbackMode(.playing(.toProgress(0.5, loopMode: .loop)))
                    .frame(width: 100, height: 100)
                
                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        }
        // Force the view to capture all touches
        .contentShape(Rectangle())
        .onTapGesture { } // Consumes tap gestures
    }
}

#Preview {
    LoadingOverlayView()
}
