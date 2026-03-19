//
//  Profile.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/09/25.
//


import SwiftUI

public struct ProfileImage: Identifiable, Codable {
    public var id: UUID = .init()
    public var url: URL?
}

public enum UserProfileImageSafeStatus: String, Codable {
    case safe
    case check
    case bad
}

public struct UploadProfileImage {
    public var id: UUID = .init()
    public var userId: UUID
    public var oldImage: UserProfileImage?
    public var newImage: UserProfileImage
    public var safeStatus: UserProfileImageSafeStatus
    public var imageIndex: Int?
    public var uploadAt: Date
    
    public init(
        userId: UUID,
        oldImage: UserProfileImage? = nil,
        newImage: UserProfileImage,
        safeStatus: UserProfileImageSafeStatus,
        imageIndex: Int? = nil,
        uploadAt: Date
    ) {
        self.userId = userId
        self.oldImage = oldImage
        self.newImage = newImage
        self.safeStatus = safeStatus
        self.imageIndex = imageIndex
        self.uploadAt = uploadAt
    }
}

public struct UploadProfileImageMetaData: Codable {
    public var id: UUID = .init()
    public var userId: UUID
    public var oldImageId: UUID?
    public var newImageId: UUID
    public var safeStatus: UserProfileImageSafeStatus
    public var internalPath: String?
    public var imageIndex: Int?
    public var uploadAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case oldImageId = "old_image_id"
        case newImageId = "new_image_id"
        case safeStatus = "safe_status"
        case internalPath = "internal_path"
        case imageIndex = "image_index"
        case uploadAt = "upload_at"
    }
}

public struct UploadProfileImageData {
    public var imageId: UUID
    public var imageData: Data
}

public struct UploadProfileImageMetaDataRequest: Codable {
    public var metadata: [UploadProfileImageMetaData]
}

public struct UploadIdentityVerificationMetaData: Codable {
    public var id: UUID = .init()
    public var userId: UUID
    public var newImageId: UUID
    public var identificationType: String
    public var internalPath: String?
    public var uploadAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case newImageId = "new_image_id"
        case identificationType = "identification_type"
        case internalPath = "internal_path"
        case uploadAt = "upload_at"
    }
}

public enum IdentificationType: String, CaseIterable, Identifiable, Codable {
    case myNumber = "マイナンバーカード"
    case driversLicense = "運転免許証"
    case passport = "パスポート"
    case residenceCard = "在留カード"
    
    public var id: String { self.rawValue }
    
    public var ratio: CGFloat {
        switch self {
        case .passport:
            return 1.42 // ID-3 Standard for Passports
        default:
            return 1.586 // Standard ID-1 for cards
        }
    }
    
    public var title: String {
        return self.rawValue
    }
}

public struct UploadIdentityVerificationMetaDataRequest: Codable {
    public var metadata: UploadIdentityVerificationMetaData
}

public struct NotificationMessage: Identifiable, Codable {
    public var id: UUID
    public var userId: UUID
    public var message: String
    public var messageType: String
    public var createdAt: Date
    public var isRead: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "message_id"
        case userId = "user_id"
        case message
        case messageType = "message_type"
        case createdAt = "created_at"
        case isRead = "is_read"
    }
}

public struct InquiryMessage: Codable {
    public var userId: UUID
    public var type: String
    public var message: String
    public var sendDate: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type
        case message
        case sendDate = "send_date"
    }
}
