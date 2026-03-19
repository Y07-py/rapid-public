//
//  YahooLocationSearchParameter.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/31.
//

import Foundation
import SwiftUI
import MapKit

public enum YahooLocationSearchDetail: String, Codable {
    case simple = "simple"
    case standard = "standard"
    case full = "full"
}

public enum YahooLocationSearchOutput: String, Codable {
    case xml = "xml"
    case json = "json"
}

public struct YahooLocationSearchParameter: Codable {
    public var appid: String? = nil
    public var device: String = "mobile"
    public var query: String? = nil
    public var cid: String? = nil
    public var uid: String? = nil
    public var gid: String? = nil
    public var id: String? = nil
    public var bid: String? = nil
    public var group: String? = nil
    public var distinct: Bool = true
    public var sort: SearchSort = .rating
    public var start: Int = .zero
    public var results: Int = 20
    public var detail: YahooLocationSearchDetail = .standard
    public var output: YahooLocationSearchOutput = .json
    public var callback: String? = nil
    public var lat: Double? = nil
    public var lon: Double? = nil
    public var dist: Float = 20
    public var bbox: String
    public var ac: String = "JP"
    public var gc: String? = nil
    public var coupon: Bool = false
    public var parking: Bool = false
    public var creditcard: Bool = false
    public var smoking: String? = nil
    public var reservation: String? = nil
    public var image: Bool = false
    public var open: String? = nil
    public var locoMode: Bool = true
    public var maxprice: Int? = nil
    public var minprice: Int? = nil
    
    init(
        query: String? = nil,
        cid: String? = nil,
        uid: String? = nil,
        gid: String? = nil,
        id: String? = nil,
        bid: String? = nil,
        group: String? = nil,
        distinct: Bool = true,
        sort: SearchSort = .rating,
        start: Int = 1,
        results: Int = 20,
        detail: YahooLocationSearchDetail = .standard,
        output: YahooLocationSearchOutput = .json,
        callback: String? = nil,
        location: CLLocation? = nil,
        dist: Float = 10,
        bbox: String,
        image: Bool = false,
        open: String? = nil,
        locoMode: Bool = true,
        maxprice: Int? = nil,
        minprice: Int? = nil,
        gc: String? = nil,
        
    ) {
        self.query = query
        self.cid = cid
        self.uid = uid
        self.gid = gid
        self.id = id
        self.bid = bid
        self.group = group
        self.distinct = distinct
        self.sort = sort
        self.start = start
        self.results = results
        self.detail = detail
        self.output = output
        self.callback = callback
        self.lat = location?.coordinate.latitude
        self.lon = location?.coordinate.longitude
        self.dist = dist
        self.bbox = bbox
        self.image = image
        self.open = open
        self.maxprice = maxprice
        self.minprice = minprice
        self.locoMode = locoMode
        self.results = results
        self.gc = gc
    }
    
    enum CodingKeys: String, CodingKey {
        case device = "device"
        case query = "query"
        case cid = "cid"
        case uid = "uid"
        case gid = "gid"
        case id = "id"
        case bid = "bid"
        case group = "group"
        case distinct = "distinct"
        case sort = "sort"
        case start = "start"
        case results = "results"
        case detail = "detail"
        case output = "output"
        case callback = "callback"
        case lat = "lat"
        case lon = "lon"
        case dist = "dist"
        case bbox = "bbox"
        case ac = "ac"
        case gc = "gc"
        case coupon = "coupon"
        case parking = "parking"
        case creditcard = "creditcard"
        case locoMode = "loco_mode"
        case smoking = "smoking"
        case reservation = "reservation"
        case image = "image"
        case open = "open"
        case maxprice = "maxprice"
        case minprice = "minprice"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        device = try container.decode(String.self, forKey: .device)
        query = try container.decode(String?.self, forKey: .query)
        cid = try container.decode(String?.self, forKey: .cid)
        uid = try container.decode(String?.self, forKey: .uid)
        gid = try container.decode(String?.self, forKey: .gid)
        id = try container.decode(String?.self, forKey: .id)
        bid = try container.decode(String?.self, forKey: .bid)
        group = try container.decode(String?.self, forKey: .group)
        distinct = try container.decode(Bool.self, forKey: .distinct)
        sort = try container.decode(SearchSort.self, forKey: .sort)
        start = try container.decode(Int.self, forKey: .start)
        results = try container.decode(Int.self, forKey: .results)
        detail = try container.decode(YahooLocationSearchDetail.self, forKey: .detail)
        output = try container.decode(YahooLocationSearchOutput.self, forKey: .output)
        callback = try container.decode(String?.self, forKey: .callback)
        lat = try container.decode(Double.self, forKey: .lat)
        lon = try container.decode(Double.self, forKey: .lon)
        dist = try container.decode(Float.self, forKey: .dist)
        bbox = try container.decode(String.self, forKey: .bbox)
        ac = try container.decode(String.self, forKey: .ac)
        gc = try container.decode(String.self, forKey: .gc)
        coupon = try container.decode(Bool.self, forKey: .coupon)
        parking = try container.decode(Bool.self, forKey: .parking)
        creditcard = try container.decode(Bool.self, forKey: .creditcard)
        smoking = try container.decode(String?.self, forKey: .smoking)
        reservation = try container.decode(String?.self, forKey: .reservation)
        image = try container.decode(Bool.self, forKey: .image)
        open = try container.decode(String?.self, forKey: .open)
        locoMode = try container.decode(Bool.self, forKey: .locoMode)
        maxprice = try container.decode(Int?.self, forKey: .maxprice)
        minprice = try container.decode(Int?.self, forKey: .minprice)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.device, forKey: .device)
        try container.encode(self.query, forKey: .query)
        try container.encode(self.cid, forKey: .cid)
        try container.encode(self.uid, forKey: .uid)
        try container.encode(self.gid, forKey: .gid)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.bid, forKey: .bid)
        try container.encode(self.group, forKey: .group)
        try container.encode(self.distinct, forKey: .distinct)
        try container.encode(self.sort, forKey: .sort)
        try container.encode(self.start, forKey: .start)
        try container.encode(self.results, forKey: .results)
        try container.encode(self.detail, forKey: .detail)
        try container.encode(self.output, forKey: .output)
        try container.encode(self.callback, forKey: .callback)
        try container.encode(self.lat, forKey: .lat)
        try container.encode(self.lon, forKey: .lon)
        try container.encode(self.dist, forKey: .dist)
        try container.encode(self.bbox, forKey: .bbox)
        try container.encode(self.ac, forKey: .ac)
        try container.encode(self.gc, forKey: .gc)
        try container.encode(self.coupon, forKey: .coupon)
        try container.encode(self.parking, forKey: .parking)
        try container.encode(self.creditcard, forKey: .creditcard)
        try container.encode(self.locoMode, forKey: .locoMode)
        try container.encode(self.smoking, forKey: .smoking)
        try container.encode(self.reservation, forKey: .reservation)
        try container.encode(self.image, forKey: .image)
        try container.encode(self.open, forKey: .open)
        try container.encode(self.maxprice, forKey: .maxprice)
        try container.encode(self.minprice, forKey: .minprice)
    }
}

public enum SearchSort: String, CaseIterable, Identifiable, Codable {
    public var id: Self { self }
    case rating = "rating"
    case score = "score"
    case review = "review"
    case price = "price"
    case dist = "dist"
    
    var description: String {
        switch self {
        case .rating:
            "レーティング"
        case .score:
            "スコア"
        case .review:
            "レビュー"
        case .price:
            "価格"
        case .dist:
            "距離"
        }
    }
}

public enum YahooLocationSearchDaysOfWeek: String, CaseIterable, Identifiable {
    public var id: Self { self }
    case sunday = "日"
    case monday = "月"
    case tuesday = "火"
    case wednesday = "水"
    case thursday = "木"
    case fryday = "金"
    case satarday = "土"
}

public struct YahooCalendarMonth: Identifiable {
    public var id: UUID = .init()
    public var dates: [YahooCalendarDay]
    public var date: Date
}

public enum YahooCalendarDayEdge: Equatable {
    case rightEnd
    case notEnd
    case leftEnd
}

public struct YahooCalendarDay: Identifiable {
    public var id: UUID = .init()
    public var date: Date
    public var past: Bool
    public var inMonth: Bool
    public var edge: YahooCalendarDayEdge
}

public struct YahooSearchFilterCity: Identifiable, Equatable {
    public var id: UUID = .init()
    public var prefecture: String
    public var city: String
    public var longitude: Double
    public var latitude: Double
}

public struct YahooLocationGenreCode: Identifiable, Equatable, Codable {
    public var id: UUID = .init()
    public var genreCode1: Int
    public var genreCode2: Int
    public var genreCode3: Int
    public var genreName1: String
    public var genreName2: String
    public var genreName3: String
    
    enum CodingKeys: String, CodingKey {
        case genreCode1 = "genre_code1"
        case genreCode2 = "genre_code2"
        case genreCode3 = "genre_code3"
        case genreName1 = "genre_name1"
        case genreName2 = "genre_name2"
        case genreName3 = "genre_name3"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        genreCode1 = try container.decode(Int.self, forKey: .genreCode1)
        genreCode2 =  try container.decode(Int.self, forKey: .genreCode2)
        genreCode3 = try container.decode(Int.self, forKey: .genreCode3)
        genreName1 = try container.decode(String.self, forKey: .genreName1)
        genreName2 = try container.decode(String.self, forKey: .genreName2)
        genreName3 = try container.decode(String.self, forKey: .genreName3)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(genreCode1, forKey: .genreCode1)
        try container.encode(genreCode2, forKey: .genreCode2)
        try container.encode(genreCode3, forKey: .genreCode3)
        try container.encode(genreName1, forKey: .genreName1)
        try container.encode(genreName2, forKey: .genreName2)
        try container.encode(genreName3, forKey: .genreName3)
    }
}

public struct YahooLocationSearchOpenDate: Codable {
    var startDate: Date?
    var endDate: Date?
    
    init(startDate: Date?, endDate: Date?) {
        self.startDate = startDate
        self.endDate = endDate
    }
    
    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startDate = try container.decode(Date?.self, forKey: .startDate)
        endDate = try container.decode(Date?.self, forKey: .endDate)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
    }
}

public struct YahooLocationSearchMetaData: Codable {
    var openDate: YahooLocationSearchOpenDate
    var parameter: YahooLocationSearchParameter
    
    init(openDate: YahooLocationSearchOpenDate, parameter: YahooLocationSearchParameter) {
        self.openDate = openDate
        self.parameter = parameter
    }
    
    enum CodingKeys: String, CodingKey {
        case openDate = "open_date"
        case parameter = "parameter"
    }
}

public struct YahooLocationSearchResponse: Codable {
    public var resultInfo: YahooLocationSearchResultInfo? = nil
    public var feature: [YahooLocationSearchFeature]? = nil
    
    enum CodingKeys: String, CodingKey {
        case resultInfo = "ResultInfo"
        case feature = "Feature"
    }
}

public struct YahooLocationSearchResultInfo: Codable {
    public var count: Int32
    public var total: Int32
    public var start: Int32
    public var latency: Float64
    public var status: Int32
    
    enum CodingKeys: String, CodingKey {
        case count = "Count"
        case total = "Total"
        case start = "Start"
        case latency = "Latency"
        case status = "Status"
    }
}

public struct YahooLocationSearchFeature: Codable, Identifiable {
    public var id: String
    public var gid: String?
    public var name: String?
    public var geometry: YahooLocationSearchGeometry?
    public var category: [String]?
    public var description: String?
    public var style: [String]?
    public var property: YahooLocationSearchProperty
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case gid = "Gid"
        case name = "Name"
        case geometry = "Geometry"
        case category = "Category"
        case description = "Description"
        case style = "Style"
        case property = "Property"
    }
}

public struct YahooLocationSearchGeometry: Codable {
    public var type: String?
    public var coordinates: String?
    
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case coordinates = "Coordinates"
    }
}

public struct YahooLocationSearchProperty: Codable {
    public var uid: String?
    public var cassetteId: String?
    public var yomi: String?
    public var country: YahooLocationSearchCountry?
    public var address: String?
    public var governmentCode: String?
    public var station: [YahooLocationSearchStation]?
    public var placeInfo: YahooLocationSearchPlaceInfo?
    public var tel1: String?
    public var genre: YahooLocationSearchGenreCode?
    public var building: YahooLocationSearchBuilding?
    public var catchCopy: String?
    public var coupon: [String]?
    public var reviewCount: [String]?
    public var detail: YahooLocationSearchDetail?
    public var style: [String]?
    
    enum CodingKeys: String, CodingKey {
        case uid = "Uid"
        case cassetteId = "CassetteId"
        case yomi = "Yomi"
        case country = "Country"
        case address = "Address"
        case governmentCode = "GovernmentCode"
        case station = "Station"
        case placeInfo = "PlaceInfo"
        case tel1 = "Tel1"
        case genre = "Genre"
        case building = "Building"
        case catchCopy = "CatchCopy"
        case coupon = "Coupon"
        case reviewCount = "ReviewCount"
        case detail = "Detail"
        case style = "Style"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(String?.self, forKey: .uid)
        cassetteId = try container.decode(String?.self, forKey: .cassetteId)
        yomi = try container.decode(String?.self, forKey: .yomi)
        country = try container.decode(YahooLocationSearchCountry?.self, forKey: .country)
        address = try container.decode(String?.self, forKey: .address)
        governmentCode = try container.decode(String?.self, forKey: .governmentCode)
        station = try container.decode([YahooLocationSearchStation]?.self, forKey: .station)
        placeInfo = try container.decode(YahooLocationSearchPlaceInfo?.self, forKey: .placeInfo)
        tel1 = try container.decode(String?.self, forKey: .tel1)
        genre = try container.decode(YahooLocationSearchGenreCode?.self, forKey: .genre)
        building = try container.decode(YahooLocationSearchBuilding?.self, forKey: .building)
        catchCopy = try container.decode(String?.self, forKey: .catchCopy)
        coupon = try container.decode([String]?.self, forKey: .coupon)
        reviewCount = try container.decode([String]?.self, forKey: .reviewCount)
        detail = try container.decode(YahooLocationSearchDetail?.self, forKey: .detail)
        style = try container.decode([String]?.self, forKey: .style)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uid, forKey: .uid)
        try container.encode(cassetteId, forKey: .cassetteId)
        try container.encode(yomi, forKey: .yomi)
        try container.encode(country, forKey: .country)
        try container.encode(address, forKey: .address)
        try container.encode(governmentCode, forKey: .governmentCode)
        try container.encode(station, forKey: .station)
        try container.encode(placeInfo, forKey: .placeInfo)
        try container.encode(tel1, forKey: .tel1)
        try container.encode(genre, forKey: .genre)
        try container.encode(building, forKey: .building)
        try container.encode(catchCopy, forKey: .catchCopy)
        try container.encode(coupon, forKey: .coupon)
        try container.encode(reviewCount, forKey: .reviewCount)
        try container.encode(detail, forKey: .detail)
        try container.encode(style, forKey: .style)
    }
}

public struct YahooLocationSearchCountry: Codable {
    public var code: String?
    public var name: String?
    
    enum CodingKeys: String, CodingKey {
        case code = "Code"
        case name = "Name"
    }
}

public struct YahooLocationSearchStation: Codable {
    public var id: String?
    public var subId: String?
    public var name: String?
    public var railway: String?
    public var exit: String?
    public var exitId: String?
    public var distance: String?
    public var time: String?
    public var geometry: YahooLocationSearchGeometry?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case subId = "SubId"
        case name = "Name"
        case railway = "Railway"
        case exit = "Exit"
        case exitId = "ExitId"
        case distance = "Distance"
        case time = "Time"
        case geometry = "Geometry"
    }
}

public struct YahooLocationSearchPlaceInfo: Codable {
    public var floorName: String?
    public var mapType: String?
    public var mapScale: String?
    
    enum CodingKeys: String, CodingKey {
        case floorName = "FloorName"
        case mapType = "MapType"
        case mapScale = "MapScale"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        floorName = try container.decode(String?.self, forKey: .floorName)
        mapType = try container.decode(String?.self, forKey: .mapType)
        mapScale = try container.decode(String?.self, forKey: .mapScale)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(floorName, forKey: .floorName)
        try container.encode(mapType, forKey: .mapType)
        try container.encode(mapScale, forKey: .mapScale)
    }
}

public struct YahooLocationSearchGenreCode: Codable {
    public var code: String?
    public var name: String?
    
    enum CodingKeys: String, CodingKey {
        case code = "Code"
        case name = "Name"
    }
}

public struct YahooLocationSearchBuilding: Codable {
    public var id: String?
    public var name: String?
    public var floor: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case floor = "Floor"
    }
}

