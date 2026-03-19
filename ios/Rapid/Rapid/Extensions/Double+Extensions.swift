//
//  Double+Extensions.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/09/09.
//

import Foundation

extension Double {
    static let TILE_SIZE: Double = 256
    static let ORIGIN: Double = TILE_SIZE / 2.0
    static let PIXELS_PER_DEGREE: Double = TILE_SIZE / 360.0
    static let PIXELS_PER_RADIAN: Double = TILE_SIZE / (2.0 * Double.pi)
    static let WGS84_EQUATION_RADIUS: Double = 6378137.0
    
    // GRS80
    static let GRS80_EQUATION_RADIUS: Double = 6378137.0
    static let GRS80_SHORT_RADIUS: Double = 6356752.31414
    static let GRS80_OBLATENESS: Double = 0.003353810681225
}
