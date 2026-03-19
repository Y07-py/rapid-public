//
//  LPLinkThumbnail.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/06.
//

import Foundation
import SwiftUI
import LinkPresentation

public struct LPLinkThumbnail: UIViewRepresentable {
    var metadata: LPLinkMetadata
    
    public func makeUIView(context: Context) -> LPLinkView {
        let view = LPLinkView(metadata: metadata)
        return view
    }
    
    public func updateUIView(_ view: LPLinkView, context: Context) {
        view.metadata = metadata
    }
}
