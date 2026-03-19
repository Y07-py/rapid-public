//
//  WaitProgressView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/11.
//

import SwiftUI

struct WaitProgressView: View {
    let scale: CGFloat
    var body: some View {
        ZStack {
            Color.gray.opacity(0.2).ignoresSafeArea()
            ProgressView("Waiting...")
                .scaleEffect(scale)
                .tint(.gray)
        }
    }
}

//#Preview {
//    WaitProgressView()
//}
