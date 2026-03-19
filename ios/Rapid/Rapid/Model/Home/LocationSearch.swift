//
//  LocationCategory.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/13.
//

import Foundation
import CoreLocation

public struct LocationCategory: Identifiable {
    public var id: UUID = .init()
    public let name: String
    public let placeType: GooglePlaceType
}

public struct LocationSearchQuery: Identifiable {
    public var id: UUID
    public var query: String
    public var createdAt: Date
}
