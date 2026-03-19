//
//  Veiw+Extension.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/07.
//

import Foundation
import SwiftUI

struct KeyboardHeightModifier: ViewModifier {
    /// Output the height from the bottom edges of the screen to the top of the keyboad when the keyboard appears.
    @Binding var keyboardHeight: CGFloat
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                    guard let info = note.userInfo,
                          let end = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = max(0, geometry.frame(in: .global).maxY - end.origin.y)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = 0
                    }
                }
        }
    }
}

extension View {
    func keyboardHeightObserber(_ height: Binding<CGFloat>) -> some View {
        self.modifier(KeyboardHeightModifier(keyboardHeight: height))
    }
}

// MARK: - Skelton modifier.
struct SkeltonModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    if isEnabled {
                        Color.white.opacity(0.3)
                            .mask(Rectangle().fill(
                                LinearGradient(gradient: .init(colors: [.clear, .white.opacity(0.5), .clear]),
                                               startPoint: .leading,
                                               endPoint: .trailing)
                            ))
                            .offset(x: -geo.size.width + (geo.size.width * 2 * phase))
                            .onAppear {
                                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                    phase = 1
                                }
                            }
                    }
                }
            }
    }
}

extension View {
    @ViewBuilder
    func skelton(isActive: Bool) -> some View {
        if isActive {
            self.redacted(reason: .placeholder)
                .modifier(SkeltonModifier(isEnabled: true))
        } else {
            self.unredacted()
        }
    }
    
    func baseShadow() -> some View {
        self
            .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
            .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
    }
}

// MARK: - Scroll Offset
struct OffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollOffsetVerticalModifier: ViewModifier {
    let coordinateSpace: CoordinateSpace
    let completion: (CGFloat) -> Void
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: OffsetPreferenceKey.self,
                            value: proxy.frame(in: coordinateSpace).maxY
                        )
                }
            )
            .onPreferenceChange(OffsetPreferenceKey.self) { value in
                DispatchQueue.main.async {
                    completion(value)
                }
            }
    }
}

extension View {
    func scrollVerticalOffset(
        in space: CoordinateSpace = .global,
        completion: @escaping (CGFloat) -> Void
    ) -> some View {
        self.modifier(ScrollOffsetVerticalModifier(coordinateSpace: space, completion: completion))
    }
}
