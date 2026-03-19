//
//  EmbeddingWeb.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/23.
//

import SwiftUI
import WebKit
import WebUI

public struct EmbeddingWebView: View {
    let url: URL
    var frameHeight: CGFloat? = nil
    var frameWidth: CGFloat? = nil
    
    public init(url: URL, height: CGFloat? = nil, width: CGFloat? = nil) {
        self.url = url
        self.frameHeight = height
        self.frameWidth = width
    }
    
    public var body: some View {
        WebViewReader { proxy in
            VStack {
                header(proxy: proxy)
                WebView(request: URLRequest(url: url))
                    .frame(width: frameWidth, height: frameHeight)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    @ViewBuilder
    private func header(proxy: WebViewProxy) -> some View{
        HStack(alignment: .center) {
            HStack(alignment: .center, spacing: 15) {
                Button(action: {
                    if proxy.canGoBack {
                        proxy.goBack()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .resizable()
                        .frame(width: 15, height: 15)
                        .foregroundStyle(proxy.canGoBack ? .gray: .gray.opacity(0.1))
                }
                .padding(.vertical, 10)
                Button(action: {
                    if proxy.canGoForward {
                        proxy.goForward()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .resizable()
                        .frame(width: 15, height: 15)
                        .foregroundStyle(proxy.canGoForward ? .gray : .gray.opacity(0.1))
                }
                .padding(.vertical, 10)
            }
            .padding(.leading, 20)
            Spacer()
        }
        .background(.ultraThinMaterial)
    }
}
