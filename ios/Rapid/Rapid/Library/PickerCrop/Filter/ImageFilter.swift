//
//  ImageFilter.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/16.
//

import Foundation
import UIKit
import CoreImage

public typealias FilterApplierType = (_ image: CIImage) -> CIImage?

public struct ImageFilter {
    var name: String = ""
    var applier: FilterApplierType?

    public init(name: String, coreImageFilterName: String) {
        self.name = name
        self.applier = ImageFilter.coreImageFilter(name: coreImageFilterName)
    }

    public init(name: String, applier: FilterApplierType?) {
        self.name = name
        self.applier = applier
    }
}

private func applyFilterSafely(
    name: String,
    to image: CIImage,
    params: [String: Any] = [:]
) -> CIImage? {
    guard let filter = CIFilter(name: name) else {
        print("❌ Unknown CIFilter:", name)
        return nil
    }
    filter.setValue(image, forKey: kCIInputImageKey)

    let allowed = Set(filter.inputKeys)
    for (k, v) in params where allowed.contains(k) {
        filter.setValue(v, forKey: k)
        
    }
    let dropped = params.keys.filter { !allowed.contains($0) }
    if !dropped.isEmpty {
        print("⚠️ Dropped keys for \(name): \(dropped)")
    }

    return filter.outputImage
}

extension ImageFilter {
    public static func coreImageFilter(name: String) -> FilterApplierType {
        return { image in
            applyFilterSafely(name: name, to: image)
        }
    }

    public static func getColor(red: Int, green: Int, blue: Int, alpha: Int = 255) -> CIColor {
        CIColor(
            red: CGFloat(red) / 255.0,
            green: CGFloat(green) / 255.0,
            blue: CGFloat(blue) / 255.0,
            alpha: CGFloat(alpha) / 255.0
        )
    }

    public static func getColorImage(red: Int, green: Int, blue: Int, alpha: Int = 255, rect: CGRect) -> CIImage {
        let color = getColor(red: red, green: green, blue: blue, alpha: alpha)
        return CIImage(color: color).cropped(to: rect)
    }

    // Clarendon
    public static func clarendonFilter(foregroundImage: CIImage) -> CIImage? {
        let bg = getColorImage(
            red: 127, green: 187, blue: 227,
            alpha: Int(255 * 0.2),
            rect: foregroundImage.extent
        )

        // Overlay → ColorControls（キーは定数 or 正しい綴り）
        let overlaid = applyFilterSafely(
            name: "CIOverlayBlendMode",
            to: foregroundImage,
            params: [kCIInputBackgroundImageKey: bg]
        )

        return overlaid.flatMap {
            applyFilterSafely(
                name: "CIColorControls",
                to: $0,
                params: [
                    kCIInputSaturationKey: 1.35,
                    kCIInputBrightnessKey: 0.05,
                    kCIInputContrastKey: 1.1
                ]
            )
        }
    }

    // Nashville
    public static func nashvilleFilter(foregroundImage: CIImage) -> CIImage? {
        let bg1 = getColorImage(red: 247, green: 176, blue: 153, alpha: Int(255 * 0.56), rect: foregroundImage.extent)
        let bg2 = getColorImage(red: 0, green: 70, blue: 150, alpha: Int(255 * 0.4), rect: foregroundImage.extent)

        return applyFilterSafely(
            name: "CIDarkenBlendMode",
            to: foregroundImage,
            params: [kCIInputBackgroundImageKey: bg1]
        )
        .flatMap {
            applyFilterSafely(
                name: "CISepiaTone",
                to: $0,
                params: [kCIInputIntensityKey: 0.2]
            )
        }
        .flatMap {
            applyFilterSafely(
                name: "CIColorControls",
                to: $0,
                params: [
                    kCIInputSaturationKey: 1.2,
                    kCIInputBrightnessKey: 0.05,
                    kCIInputContrastKey: 1.1
                ]
            )
        }
        .flatMap {
            applyFilterSafely(
                name: "CILightenBlendMode",
                to: $0,
                params: [kCIInputBackgroundImageKey: bg2]
            )
        }
    }

    // 1977
    public static func apply1977Filter(ciImage: CIImage) -> CIImage? {
        let tint = getColorImage(red: 243, green: 106, blue: 108, alpha: Int(255 * 0.1), rect: ciImage.extent)

        let adjusted = applyFilterSafely(
            name: "CIColorControls",
            to: ciImage,
            params: [
                kCIInputSaturationKey: 1.3,
                kCIInputBrightnessKey: 0.1,
                kCIInputContrastKey: 1.05
            ]
        )
        .flatMap {
            applyFilterSafely(
                name: "CIHueAdjust",
                to: $0,
                params: [kCIInputAngleKey: 0.3]
            )
        }

        let screened = adjusted.flatMap {
            applyFilterSafely(
                name: "CIScreenBlendMode",
                to: tint,
                params: [kCIInputBackgroundImageKey: $0]
            )
        }

        return screened.flatMap {
            applyFilterSafely(
                name: "CIToneCurve",
                to: $0,
                params: [
                    "inputPoint0": CIVector(x: 0, y: 0),
                    "inputPoint1": CIVector(x: 0.25, y: 0.20),
                    "inputPoint2": CIVector(x: 0.5, y: 0.5),
                    "inputPoint3": CIVector(x: 0.75, y: 0.80),
                    "inputPoint4": CIVector(x: 1, y: 1)
                ]
            )
        }
    }

    // Toaster
    public static func toasterFilter(ciImage: CIImage) -> CIImage? {
        let w = ciImage.extent.width
        let h = ciImage.extent.height
        let center = CIVector(x: w / 2.0, y: h / 2.0)
        let r0 = min(w / 4.0, h / 4.0)
        let r1 = min(w / 1.5, h / 1.5)

        let color0 = getColor(red: 128, green: 78, blue: 15)
        let color1 = getColor(red: 79, green: 0, blue: 79)

        // 円グラデ生成（nil 安全）
        let circle = CIFilter(name: "CIRadialGradient", parameters: [
            kCIInputCenterKey: center,
            "inputRadius0": r0,
            "inputRadius1": r1,
            "inputColor0": color0,
            "inputColor1": color1
        ])?.outputImage?.cropped(to: ciImage.extent)

        let adjusted = applyFilterSafely(
            name: "CIColorControls",
            to: ciImage,
            params: [
                kCIInputSaturationKey: 1.0,             
                kCIInputBrightnessKey: 0.01,
                kCIInputContrastKey: 1.1
            ]
        )

        guard let circle = circle, let base = adjusted else { return adjusted }

        return applyFilterSafely(
            name: "CIScreenBlendMode",
            to: base,
            params: [kCIInputBackgroundImageKey: circle]
        )
    }
}
