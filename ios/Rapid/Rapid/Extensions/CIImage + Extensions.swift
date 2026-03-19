//
//  CIImage + Extensions.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/16.
//

import Foundation
import UIKit

extension CIImage {
    func toUIImage() -> UIImage {
        let context: CIContext = CIContext.init(options: nil)
        let cgImage: CGImage = context.createCGImage(self, from: self.extent)!
        let image: UIImage = UIImage(cgImage: cgImage)
        return image
    }
}
