//
//  UserModel.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/20.
//

import Foundation
import SwiftUI

public struct RapidUser: Codable, Identifiable {
    public var id: UUID
    var userName: String?
    var birthDate: Date?
    var residence: String?
    var thoughtMarriage: String?
    var bloodType: String?
    var academicBackground: String?
    var income: String?
    var profession: String?
    var drinkingFrequency: String?
    var smokingFrequency: String?
    var childStatus: String?
    var height: Int?
    var mbti: String?
    var userScore: Double?
    var settingStatus: Bool
    var introduction: String?
    var holidayType: String?
    var sex: String?
    var bodyType: String?
    var subscriptionStatus: String?
    var totalPoint: Int?
    var isIdentityVerified: Bool?
    public var identityVerifiedStatus: String?
    
    public init(
        id: UUID,
        userName: String? = nil,
        birthDate: Date? = nil,
        residence: String? = nil,
        thoughtMarriage: String? = nil,
        bloodType: String? = nil,
        academicBackground: String? = nil,
        income: String? = nil,
        profession: String? = nil,
        drinkingFrequency: String? = nil,
        smokingFrequency: String? = nil,
        childStatus: String? = nil,
        height: Int? = nil,
        mbti: String? = nil,
        userScore: Double? = nil,
        settingStatus: Bool,
        introduction: String? = nil,
        holidayType: String? = nil,
        sex: String? = nil,
        bodyType: String? = nil,
        subscriptionStatus: String? = nil,
        totalPoint: Int? = nil,
        isIdentityVerified: Bool? = nil
    ) {
        self.id = id
        self.userName = userName
        self.birthDate = birthDate
        self.residence = residence
        self.thoughtMarriage = thoughtMarriage
        self.bloodType = bloodType
        self.academicBackground = academicBackground
        self.income = income
        self.profession = profession
        self.drinkingFrequency = drinkingFrequency
        self.smokingFrequency = smokingFrequency
        self.childStatus = childStatus
        self.height = height
        self.mbti = mbti
        self.userScore = userScore
        self.settingStatus = settingStatus
        self.introduction = introduction
        self.holidayType = holidayType
        self.sex = sex
        self.bodyType = bodyType
        self.subscriptionStatus = subscriptionStatus
        self.totalPoint = totalPoint
        self.isIdentityVerified = isIdentityVerified
        self.identityVerifiedStatus = "unverified"
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case userName = "user_name"
        case birthDate = "birth_date"
        case residence
        case thoughtMarriage = "thought_marriage"
        case bloodType = "blood_type"
        case academicBackground = "academic_background"
        case income
        case profession
        case drinkingFrequency = "drinking_frequency"
        case smokingFrequency = "smoking_frequency"
        case childStatus = "child_status"
        case height
        case mbti
        case introduction
        case userScore = "user_score"
        case settingStatus = "setting_status"
        case holidayType = "holiday_type"
        case sex
        case bodyType = "body_type"
        case subscriptionStatus = "subscription_status"
        case totalPoint = "total_point"
        case isIdentityVerified = "is_identity_verified"
        case identityVerifiedStatus = "identity_verified_status"
    }
}

extension RapidUser {
    public mutating func addPoint(point: Int) {
        if var totalPoint = self.totalPoint {
            totalPoint += point
            self.totalPoint = totalPoint
        }
    }
}

public struct RapidUserWithProfile: Identifiable, Equatable {
    public static func == (lhs: RapidUserWithProfile, rhs: RapidUserWithProfile) -> Bool {
        lhs.user.id == rhs.user.id
    }
    
    public var id: UUID = .init()
    public var user: RapidUser
    public var profileImages: [UserProfileImage]
}

public struct Liker: Identifiable {
    public let id: UUID
    public let user: RapidUserWithProfile
    public let likedAt: Date
    public let recruitmentId: UUID
    public var isRead: Bool
    
    public init(id: UUID, user: RapidUserWithProfile, likedAt: Date, recruitmentId: UUID, isRead: Bool) {
        self.id = id
        self.user = user
        self.likedAt = likedAt
        self.recruitmentId = recruitmentId
        self.isRead = isRead
    }
}

public struct EmailCheckStatus: Codable {
    let exists: Bool
}

public struct UserModel: Codable, Identifiable, Equatable {
    public static func == (lhs: UserModel, rhs: UserModel) -> Bool {
        lhs.profile.uid == rhs.profile.uid
    }
    
    public var id: UUID = .init()
    public var profile: UserProfile
    public var keywordTags: [UserProfileKeyWordTag]
    public var profileImages: [UserProfileImage]
}

public struct UserProfile: Codable {
    var uid: UUID
    var createdAt: Date
    var userName: String
    var birthDate: Date
    var height: CGFloat?
    var prefecture: String?
    var bloodType: String?
    var smokingStyle: String?
    var academicBackground: String?
    var annualIncome: String?
    var profession: String?
    var matchingPurpose: String?
    var drink: String?
    var childStatus: String?
    var introduction: String
    
    init(
         uid: UUID,
         userName: String,
         birthDate: Date,
         height: CGFloat?,
         prefecture: Prefecture?,
         bloodType: BloodType?,
         smokingStyle: Smoking?,
         academicBackground: AcademicBackground?,
         annualIncome: Income?,
         profession: Profession?,
         matchingPurpose: MatchingPurpose?,
         drink: Drinking?,
         childStatus: ChildStatus?,
         introduction: String
    ) {
        self.uid = uid
        self.createdAt = .init()
        self.userName = userName
        self.birthDate = birthDate
        self.height = height
        self.prefecture = prefecture?.name
        self.bloodType = bloodType?.type.rawValue
        self.smokingStyle = smokingStyle?.style.rawValue
        self.academicBackground = academicBackground?.academic.rawValue
        self.annualIncome = annualIncome?.income.rawValue
        self.profession = profession?.name
        self.matchingPurpose = matchingPurpose?.purpose.rawValue
        self.drink = drink?.style.rawValue
        self.childStatus = childStatus?.status.rawValue
        self.introduction = introduction
    }
    
    enum CodingKeys: String, CodingKey {
        case uid = "uid"
        case createdAt = "created_at"
        case userName = "user_name"
        case birthDate = "birth_date"
        case height = "height"
        case prefecture = "prefecture"
        case bloodType = "blood_type"
        case smokingStyle = "smoking_style"
        case academicBackground = "academic_background"
        case annualIncome = "annual_income"
        case profession = "profession"
        case matcingPurpose = "matching_purpose"
        case drink = "drink"
        case childStatus = "child_status"
        case introduction = "introduction"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(UUID.self, forKey: .uid)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        userName = try container.decode(String.self, forKey: .userName)
        birthDate = try container.decode(Date.self, forKey: .birthDate)
        height = try container.decodeIfPresent(CGFloat.self, forKey: .height)
        prefecture = try container.decodeIfPresent(String.self, forKey: .prefecture)
        bloodType = try container.decodeIfPresent(String.self, forKey: .bloodType)
        smokingStyle = try container.decodeIfPresent(String.self, forKey: .smokingStyle)
        academicBackground = try container.decodeIfPresent(String.self, forKey: .academicBackground)
        annualIncome = try container.decodeIfPresent(String.self, forKey: .annualIncome)
        profession = try container.decodeIfPresent(String.self, forKey: .profession)
        matchingPurpose = try container.decodeIfPresent(String.self, forKey: .matcingPurpose)
        drink = try container.decodeIfPresent(String.self, forKey: .drink)
        childStatus = try container.decodeIfPresent(String.self, forKey: .childStatus)
        introduction = try container.decode(String.self, forKey: .introduction)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uid, forKey: .uid)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(userName, forKey: .userName)
        try container.encode(birthDate, forKey: .birthDate)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(prefecture, forKey: .prefecture)
        try container.encodeIfPresent(bloodType, forKey: .bloodType)
        try container.encodeIfPresent(smokingStyle, forKey: .smokingStyle)
        try container.encodeIfPresent(academicBackground, forKey: .academicBackground)
        try container.encodeIfPresent(annualIncome, forKey: .annualIncome)
        try container.encodeIfPresent(profession, forKey: .profession)
        try container.encodeIfPresent(matchingPurpose, forKey: .matcingPurpose)
        try container.encodeIfPresent(drink, forKey: .drink)
        try container.encodeIfPresent(childStatus, forKey: .childStatus)
        try container.encode(introduction, forKey: .introduction)
    }
}

public struct UserProfileKeyWordTag: Codable, Identifiable {
    public var id: UUID
    public var uid: UUID
    public var keyword: String
    public var category: String
    
    init(uid: UUID, keywordTag: KeyWordTag) {
        self.id = keywordTag.id
        self.uid = uid
        self.keyword = keywordTag.keyword
        self.category = keywordTag.category.rawValue
    }
}

public struct UserProfileImage: Codable, Identifiable {
    public var id: UUID
    public var image: Data? = nil
    public var expiresIn: Int
    public var expiresAt: Date
    public var imageURL: URL? = nil
    public var isUnderReview: Bool = false
    public var token: String? = nil
    
    init(image: UIImage, id: UUID = .init(), expiresIn: Int = 24 * 60 * 60, isUnderReview: Bool = false) {
        self.id = id
        self.image = image.jpegData(compressionQuality: 1.0)!
        self.expiresIn = expiresIn
        self.expiresAt = Calendar.current.date(byAdding: .second, value: expiresIn, to: Date())!
        self.isUnderReview = isUnderReview
    }
    
    init(imageURL: URL, id: UUID = .init(), expiresIn: Int = 24 * 60 * 60, isUnderReview: Bool = false, token: String? = nil) {
        self.id = id
        self.imageURL = imageURL
        self.expiresIn = expiresIn
        self.expiresAt = Calendar.current.date(byAdding: .second, value: expiresIn, to: .now)!
        self.isUnderReview = isUnderReview
        self.token = token
    }
}

public struct LikerUserId: Codable, Identifiable {
    public var id: UUID = .init()
    public var likerId: String
    public var createdAt: Date = .now
    
    public init(likerId: String) {
        self.likerId = likerId
    }
}

public struct LikerModel: Codable, Identifiable, Equatable {
    public var id: UUID = .init()
    public var user: UserModel
    public var recruitmentId: UUID
    public var createdAt: Date
    
    public init(user: UserModel, recruitmentId: UUID, createdAt: Date) {
        self.user = user
        self.recruitmentId = recruitmentId
        self.createdAt = createdAt
    }
}

public struct UserAuthentication: Codable {
    public var userId: UUID
    public var createdAt: Date
    public var lastSignInAt: Date?
    public var email: String?
    public var phoneNumber: String?
    public var provider: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case createdAt = "created_at"
        case lastSignInAt = "last_sign_in_at"
        case email
        case phoneNumber = "phone_number"
        case provider
    }
}

public struct ProfileUploadedImage: Codable {
    public var userId: UUID
    public var imageIndex: Int
    public var storagePath: String
    public var createdAt: Date
    public var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case imageIndex = "image_index"
        case storagePath = "storage_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
