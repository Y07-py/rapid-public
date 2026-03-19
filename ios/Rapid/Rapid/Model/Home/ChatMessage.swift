//
//  ChatMessage.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/01.
//

import Foundation
import SwiftUI
import OrderedCollections

public enum MessageContentType: String {
    case text = "text"
    case image = "image"
    case video = "video"
}

public struct ChatMessage: Identifiable, Codable {
    public var id: UUID
    public var toUserId: UUID
    public var fromUserId: UUID
    public var roomId: UUID
    public var context: String
    public var contextType: String
    public var createdAt: Date
    public var updatedAt: Date
    public var checked: Bool
    public var checkedAt: Date?
    
    public var image: UIImage?
    
    enum CodingKeys: String, CodingKey {
        case id = "message_id"
        case toUserId = "to_user_id"
        case fromUserId = "from_user_id"
        case roomId = "room_id"
        case context
        case contextType = "context_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case checked
        case checkedAt = "checked_at"
    }
    
    public init(
        id: UUID = .init(),
        toUserId: UUID,
        fromUserId: UUID,
        roomId: UUID,
        context: String,
        contextType: String,
        createdAt: Date,
        updatedAt: Date,
        checked: Bool,
        checkedAt: Date? = nil,
        image: UIImage? = nil
    ) {
        self.id = id
        self.toUserId = toUserId
        self.fromUserId = fromUserId
        self.roomId = roomId
        self.context = context
        self.contextType = contextType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.checked = checked
        self.checkedAt = checkedAt
        self.image = image
    }
    
    public func buildImageMessageURL() async -> URL? {
        guard contextType == "image" else { return nil }
        
        do {
            return try await SupabaseManager.shared.buildPresignedURLForMessageImage(
                roomId: roomId,
                messageId: UUID(uuidString: context)!,
                expiresIn: 60 * 60
            )
        } catch let error {
            print("Failed to build presign url: \(error.localizedDescription)")
        }
        return nil
    }
}

public struct ChatRoom: Identifiable, Codable {
    public var id: UUID = .init()
    public let toUserId: UUID
    public let fromUserId: UUID
    public let createdAt: Date
    public let recruitmentId: UUID
    public var talkCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id = "room_id"
        case toUserId = "to_user_id"
        case fromUserId = "from_user_id"
        case createdAt = "created_at"
        case recruitmentId = "recruitment_id"
        case talkCount = "talk_count"
    }
}

public struct ChatRoomWithRecruitment: Identifiable {
    public var id: UUID = .init()
    public var chatRoom: ChatRoom
    public var recruitment: RecruitmentWithRelations
    public var places: [GooglePlacesSearchPlaceWrapper]
    public var roomUser: RapidUserWithProfile
    public var messages: [ChatMessage]
    public var unReadCount: Int
    public var lastMessage: String? = nil
    public var isReported: Bool = false
}

public struct ChatRoomLog: Codable {
    public var id: UUID
    public var userId: UUID
    public var roomId: UUID
    public var enterDate: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "uid"
        case userId = "user_id"
        case roomId = "room_id"
        case enterDate = "enter_date"
    }
}

public struct CallAlertModel: Equatable {
    public var roomId: String
    public var caller: UserModel
}

public struct BlockedUser: Identifiable, Codable {
    public var id: UUID = .init()
    public let userId: UUID
    public let blockedUserId: UUID
    public let blockedAt: Date
    
    init(userId: UUID, blockedUserId: UUID, blockedAt: Date) {
        self.userId = userId
        self.blockedUserId = blockedUserId
        self.blockedAt = blockedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case blockedUserId = "blocked_user_id"
        case blockedAt = "blocked_at"
    }
}

public struct ChatMessageNotification: Codable {
    public var id: UUID
    public var userId: UUID
    public var roomId: UUID
    public var isOn: Bool
    public var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case roomId = "room_id"
        case isOn = "is_on"
        case updatedAt = "updated_at"
    }
}

public struct ChatRoomReport: Codable {
    public var reportUserId: UUID
    public var targetUserId: UUID
    public var roomId: UUID
    public var createdAt: Date
    public var reportType: String
    public var report: String
    
    enum CodingKeys: String, CodingKey {
        case reportUserId = "report_user_id"
        case targetUserId = "target_user_id"
        case roomId = "room_id"
        case createdAt = "created_at"
        case reportType = "report_type"
        case report
    }
}
