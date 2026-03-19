//
//  HttpRetryPolicy.swift
//  Http
//
//  Created by 木本瑛介 on 2025/12/31.
//

import Foundation

public enum HttpRetryPolicy: Hashable {
    case fixedBackoff(Int, TimeInterval)
    case exponentialBackoff(Int, TimeInterval)
}
