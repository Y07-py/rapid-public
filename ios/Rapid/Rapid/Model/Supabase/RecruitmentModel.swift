//
//  Recruitment.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/10/02.
//

import Foundation
import SwiftUI

public struct RecruitmentModel: Codable {
    public var id: UUID = .init()
    public var uid: UUID
    public var createdAt: Date = .init()
    public var updatedAt: Date = .init()
    
    enum CodingKeys: String, CodingKey {
        case id = "recruitment_id"
        case uid
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct RecruitmentFSQ: Codable, Identifiable {
    public var id: UUID = .init()
    public var uid: UUID
    public var recruitmentId: UUID
    public var fsqPlaceId: String?
    
    init(recruitmentId: UUID, fsqPlaceId: String?, uid: UUID) {
        self.recruitmentId = recruitmentId
        self.fsqPlaceId = fsqPlaceId
        self.uid = uid
    }
    
    enum CodingKeys: String, CodingKey {
        case uid
        case recruitmentId = "recruitment_id"
        case fsqPlaceId = "fsq_place_id"
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uid, forKey: .uid)
        try container.encode(recruitmentId, forKey: .recruitmentId)
        try container.encode(fsqPlaceId, forKey: .fsqPlaceId)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(UUID.self, forKey: .uid)
        recruitmentId = try container.decode(UUID.self, forKey: .recruitmentId)
        fsqPlaceId = try container.decode(String?.self, forKey: .fsqPlaceId)
    }
}
