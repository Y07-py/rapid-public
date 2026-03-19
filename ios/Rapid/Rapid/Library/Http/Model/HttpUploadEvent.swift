//
//  File.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/09.
//

import Foundation

public enum HttpUploadEvent: Sendable {
    case started
    case progress(bytesUpload: Int, totalBytes: Int)
    case finished(url: URL)
}
