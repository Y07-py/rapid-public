//
//  UserLocation.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/31.
//

import Foundation
import CoreLocation

public struct UserLocation: Codable {
    let longitude: CLLocationDegrees
    let latitude: CLLocationDegrees
}
