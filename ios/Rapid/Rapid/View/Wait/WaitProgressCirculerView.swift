//
//  WaitProgressCirculerView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/21.
//

import Foundation
import SwiftUI

struct WaitProgressCirculerView: View {
    @State private var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.37)
                .stroke(Color.blue, lineWidth: 15)
                .frame(width: 100, height: 100, alignment: .center)
                .rotationEffect(Angle(degrees: isLoading ? 0 : 360))
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 1.0)
                .repeatForever(autoreverses: false)) {
                    isLoading.toggle()
                }
        }
    }
}

#Preview {
    WaitProgressCirculerView()
}
