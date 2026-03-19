//
//  ImagePrewarmer.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/19.
//

import Foundation
import UIKit
import ImageIO
import MobileCoreServices

actor ImagePrewarmer {
    static let shared = ImagePrewarmer()
    
    func prewarmAssets(names: [String], targetSize: CGSize) async {
        await withTaskGroup(of: Void.self) { group in
            for name in names {
                group.addTask {
                    guard let ui = UIImage(named: name),
                          let data = ui.pngData() ?? ui.jpegData(compressionQuality: 0.9),
                          let thumb = downsample(imageData: data, to: targetSize) else { return }
                    await ThumbnailCache.shared.set(thumb, for: "asset:\(name)")
                }
            }
        }
    }
}
