//
//  ThumnailCache.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/19.
//

import SwiftUI
import UIKit
import ImageIO
import MobileCoreServices


actor ThumbnailCache {
    static let shared = ThumbnailCache()
    
    private let memory = NSCache<NSString, UIImage>()
    private lazy var diskDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("thumb-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    func image(for key: String) -> UIImage? {
        memory.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, for key: String) {
        memory.setObject(image, forKey: key as NSString)
        
        if let data = image.pngData() {
            try? data.write(to: diskDir.appendingPathComponent(key.sanitizedFilename() + ".png"), options: .atomic)
        }
    }
    
    func loadFromDisk(for key: String) async -> UIImage? {
        let url = diskDir.appendingPathComponent(key.sanitizedFilename() + ".png")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let scale = await MainActor.run { UIScreen.main.scale }
        return UIImage(data: data, scale: scale)
    }
    
    func clearMemory() {
        memory.removeAllObjects()
    }
}

func downsample(imageData: Data, to targetSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
    let sourceOptions: [CFString: Any] = [
        kCGImageSourceShouldCache: false,
        kCGImageSourceShouldCacheImmediately: false
    ]
    guard let src = CGImageSourceCreateWithData(imageData as CFData, sourceOptions as CFDictionary) else { return nil }
    
    let maxPixel = Int(max(targetSize.width, targetSize.height) * scale)
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixel
    ]
    
    guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
    return UIImage(cgImage: cg)
}
