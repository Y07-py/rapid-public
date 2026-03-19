//
//  Recruitment.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/10/13.
//

import Foundation
import SwiftUI

public struct RecruitmentUser: Codable {
    public var profile: UserProfile?
    public var profileUrls: [UserProfileImageURLForRecruitment]?
    
    enum CodingKeys: String, CodingKey {
        case profile
        case profileUrls = "profile_urls"
    }
}

public struct UserProfileImageURLForRecruitment: Codable, Identifiable {
    public var id: UUID = .init()
    public var url: String?
    public var expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case url
        case expiresAt = "expires_at"
    }
}

public struct LikePair: Codable {
    public var id: UUID = .init()
    public var fromUserId: UUID
    public var toUserId: UUID
    public var likedAt: Date
    public var matched: Bool
    public var isRead: Bool
    public var recruitmentId: UUID
    public var grade: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case likedAt = "liked_at"
        case matched
        case isRead = "is_read"
        case recruitmentId = "recruitment_id"
        case grade
    }
}

public struct MatchPair: Codable {
    public var id: UUID
    public var userId: UUID
    public var matchUserId: UUID
    public var matchedAt: Date
    public var roomId: UUID
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case matchUserId = "match_user_id"
        case matchedAt = "matched_at"
        case roomId = "room_id"
    }
}


// MARK: - Recruitment model
public struct RecruitmentWithUserProfile: Identifiable {
    public var id: UUID = .init()
    public var profile: RapidUserWithProfile
    public var places: [GooglePlacesSearchPlaceWrapper]
    public var recruitment: RecruitmentWithLike
}

public struct RecruitmentMessage: Codable {
    public var content: String
    public var tags: [String]
}

public enum RecruitmentDateType: Hashable {
    case free
    case date
}

public struct Recruitment: Codable, Identifiable {
    public var id: UUID
    public var uid: UUID?
    public var message: String?
    public var postDate: Date?
    public var expiresDate: Date?
    public var viewCount: Int?
    public var postUserAge: Int?
    public var postUserSex: String?
    public var messageScore: Double?
    public var status: RecruitmentStatus?
    
    enum CodingKeys: String, CodingKey {
        case id = "recruitment_id"
        case uid = "user_id"
        case message
        case postDate = "post_date"
        case expiresDate = "expires_date"
        case viewCount = "view_count"
        case postUserAge = "post_user_age"
        case postUserSex = "post_user_sex"
        case messageScore = "message_score"
        case status
    }
}

public enum RecruitmentStatus: String, Codable {
    case active = "active"
    case closed = "closed"
}

public struct RecruitmentPlace: Codable, Identifiable {
    public var id: UUID
    public var placeId: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "recruitment_id"
        case placeId = "place_id"
    }
}

public struct RecruitmentHashTag: Codable, Identifiable {
    public var id: UUID
    public var hashTag: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "recruitment_id"
        case hashTag = "hash_tag"
    }
}

public struct RecruitmentPlaceType: Codable, Identifiable {
    public var id: UUID
    public var placeType: GooglePlaceType?
    
    enum CodingKeys: String, CodingKey {
        case id = "recruitment_id"
        case placeType = "place_type"
    }
}

public struct RecruitmentLikeUsers: Codable, Identifiable {
    public var id: UUID
    public var uid: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id = "recruitment_id"
        case uid
    }
}

public struct RecruitmentWithRelations: Codable, Identifiable {
    public var id: UUID
    public let postDate: Date?
    public let expiresDate: Date?
    public let viewCount: Int?
    public let postUserAge: Int?
    public let postUserSex: String?
    public let messageScore: Double?
    public let message: String?
    public let status: String?
    public let userId: UUID?
    public let recruitmentHashTags: [RecruitmentHashTag]?
    public let recruitmentPlaces: [RecruitmentPlace]?
    public let recruitmentPlaceTypes: [RecruitmentPlaceType]?
    
    enum CodingKeys: String, CodingKey {
        case id = "recruitment_id"
        case postDate = "post_date"
        case expiresDate = "expires_date"
        case viewCount = "view_count"
        case postUserAge = "post_user_age"
        case postUserSex = "post_user_sex"
        case messageScore = "message_score"
        case message
        case status
        case userId = "user_id"
        case recruitmentHashTags = "recruitment_hash_tags"
        case recruitmentPlaces = "recruitment_places"
        case recruitmentPlaceTypes = "recruitment_place_types"
    }
    
    public func makeRecruitment() -> Recruitment {
        return Recruitment(
            id: id,
            uid: userId,
            message: message ,
            postDate: postDate,
            expiresDate: expiresDate,
            viewCount: viewCount,
            postUserAge: postUserAge,
            postUserSex: postUserSex,
            messageScore: messageScore,
            status: RecruitmentStatus(rawValue: status ?? "")
        )
    }
}

public struct LikeRecruitment: Codable {
    public var id: UUID
    public var userId: UUID
    public var recruitmentId: UUID
    public var likedAt: Date
    public var grade: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case recruitmentId = "recruitment_id"
        case likedAt = "liked_at"
        case grade
    }
}

public struct RecruitmentWithLike: Codable {
    public var like: LikeRecruitment?
    public var recruitmentWithRelations: RecruitmentWithRelations
    
    enum CodingKeys: String, CodingKey {
        case like
        case recruitmentWithRelations = "recruitment_with_relations"
    }
}

public struct FetchRecruitmentRequestParamater: Codable {
    public var userId: UUID
    public var offset: Int
    public var limit: Int
    public var filterParamater: FetchRecruitmentRequestParamaterWithFilter?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case offset
        case limit
        case filterParamater = "filter_paramater"
    }
}

public struct FetchRecruitmentRequestParamaterWithFilter: Codable {
    public var ageRange: FetchRecruitmentRequestParamaterWithAgeRange?
    public var residenceRadius: Double?
    public var locationKeyword: String?
    public var sortLogin: Bool
    
    enum CodingKeys: String, CodingKey {
        case ageRange = "age_range"
        case residenceRadius = "residence_radius"
        case locationKeyword = "location_keyword"
        case sortLogin = "sort_login"
    }
}

public struct FetchRecruitmentRequestParamaterWithAgeRange: Codable {
    public var fromAge: Int
    public var toAge: Int
    
    enum CodingKeys: String, CodingKey {
        case fromAge = "from_age"
        case toAge = "to_age"
    }
}

public struct SpotHistory: Codable, Identifiable {
    public var id: UUID = .init()
    public var userId: UUID
    public var placeId: String?
    public var usedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case placeId = "place_id"
        case usedAt = "used_at"
    }
}

public struct PostRecruitmentRequest: Codable {
    public var recruitment: Recruitment
    public var places: [RecruitmentPlace]
    public var hashTags: [RecruitmentHashTag]
    public var placeTypes: [RecruitmentPlaceType]
    
    enum CodingKeys: String, CodingKey {
        case recruitment
        case places
        case hashTags = "hash_tags"
        case placeTypes = "place_types"
    }
}
