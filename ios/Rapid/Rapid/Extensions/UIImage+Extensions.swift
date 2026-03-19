//
//  UIImage+Extensions.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/16.
//

import Foundation
import UIKit

extension UIImage {
    func toCIImage() -> CIImage? {
        return self.ciImage ?? CIImage(cgImage: self.cgImage!)
    }
    
    func resize(width: CGFloat, height: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: height)
        return UIGraphicsImageRenderer(size: size).image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Crops the image to the specified rect in the coordinate system of a view of the given size.
    /// This assumes the image is displayed with aspectFill in the view.
    func crop(to rect: CGRect, in viewSize: CGSize) -> UIImage? {
        // 1. Normalize image orientation to .up so that cgImage coordinates match UI coordinates
        let normalizedImage = self.normalizeOrientation()
        
        let imageSize = normalizedImage.size
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        // 2. Calculate how the image is drawn within the viewSize using aspectFill
        var drawSize: CGSize
        if imageAspect > viewAspect {
            drawSize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        } else {
            drawSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        }
        
        let offsetX = (viewSize.width - drawSize.width) / 2
        let offsetY = (viewSize.height - drawSize.height) / 2
        
        // 3. Map the rect to image pixel coordinates
        let scale = imageSize.width / drawSize.width
        let cropRect = CGRect(
            x: (rect.origin.x - offsetX) * scale,
            y: (rect.origin.y - offsetY) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        
        // 4. Perform cropping using CGImage
        guard let cgImage = normalizedImage.cgImage?.cropping(to: cropRect) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Normalizes the orientation of the image to .up while preserving scale.
    private func normalizeOrientation() -> UIImage {
        if self.imageOrientation == .up { return self }
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = self.scale
        
        return UIGraphicsImageRenderer(size: self.size, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: self.size))
        }
    }
}
