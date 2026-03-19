//
//  PickerCropMediaItem.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/16.
//

import Foundation
import UIKit
import AVFoundation
import Photos

public enum PickerCropMediaItem {
    case photo(p: PickerCropPhoto)
}

public class PickerCropPhoto {
    public var image: UIImage { return modifiedImage ?? originalImage }
    public let originalImage: UIImage
    public var modifiedImage: UIImage?
    public let fromCamera: Bool
    public let exifMeta: [String: Any]?
    public var asset: PHAsset?
    public var url: URL?
    
    public init(image: UIImage,
                exifMeta: [String: Any]? = nil,
                fromCamera: Bool = false,
                asset: PHAsset? = nil,
                url: URL? = nil) {
        self.originalImage = image
        self.modifiedImage = nil
        self.fromCamera = fromCamera
        self.exifMeta = exifMeta
        self.asset = asset
        self.url = url
    }
}
