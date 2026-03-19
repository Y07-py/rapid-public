//
//  UnknownView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/10.
//

import Foundation
import SwiftUI

struct ThumbnailView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.mainColor, .thirdColor]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Image("rapid_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
        }
    }
}
