//
//  String+Extensions.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/19.
//

import Foundation

extension String {
    func sanitizedFilename() -> String {
        self.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
    }
}

// MARK: - URL of Proxy Server
extension String {
    static let proxyEndPoint: String = "https://rapid-backend.com"
    static let verification: String = proxyEndPoint + "/api/user/verification"
    static let nearbySearch: String = proxyEndPoint + "/api/nearby_search"
    static let textSearch: String = proxyEndPoint + "/api/text_search"
    static let fetchRecruitment: String = proxyEndPoint + "/api/fetch_recruitment"
    static let getPlaceDetails: String = proxyEndPoint + "/api/get_place_details"
    static let searchNearbyTransports: String = proxyEndPoint + "/api/search_nearby_transports"
    static let insertLikePair: String = proxyEndPoint + "/api/user/insert_like_pair"
    static let insertMatchPair: String = proxyEndPoint + "/api/user/insert_match_pair"
    static let makeChatRoom: String = proxyEndPoint + "/api/user/make_chatroom"
    static let sendMessage: String = proxyEndPoint + "/api/user/send_message"
    static let registFcmPayload: String = proxyEndPoint + "/api/fcm/regist"
    static let sendLike: String = proxyEndPoint + "/api/user/send_like"
    static let blockingUser: String = proxyEndPoint + "/api/user/blocking_user"
    static let makeVoiceChatRoom: String = proxyEndPoint + "/api/user/make_voice_chat_room"
    static let registVoIPDeviceToken: String = proxyEndPoint + "/api/sns/voip/regist_voip_device"
    static let fetchVoiceChatRoom: String = proxyEndPoint + "/api/voice_chat/fetch_voice_chat_rooms"
    static let sendLikeToVoiceChatRoom: String = proxyEndPoint + "/api/voice_chat/send_like_to_voice_chat_room"
    static let sendCallMessage: String = proxyEndPoint + "/api/voice_chat/send_call_message"
    static let uploadProfileImageMetadata: String = proxyEndPoint + "/api/user/upload_profile_image_metadata"
    static let uploadIdentityVerificationMetadata: String = proxyEndPoint + "/api/user/upload_identity_verification_metadata"
    static let updateProfileMetadata: String = proxyEndPoint + "/api/user/update_user_profile"
    static let uploadProfile: String = proxyEndPoint + "/api/user/upload_profile"
    static let uploadImage: String = proxyEndPoint + "/api/upload/" // Tusd endpoint
    static let fetchUnderReviewMetadata: String = proxyEndPoint + "/api/user/under_review_metadata"
    static let fetchUnderReviewImage: String = proxyEndPoint + "/api/user/under_review_image/"
    static let postRecruitment: String = proxyEndPoint + "/api/post_recruitment"
    static let postInquiryMessage: String = proxyEndPoint + "/api/user/post_inquiry_message"
    static let postChatRoomReport: String = proxyEndPoint + "/api/user/post_chat_room_report"
    static let getReportedRoomIds: String = proxyEndPoint + "/api/user/get_reported_room_ids"
    static let checkMaintenance: String = proxyEndPoint + "/api/system/maintenance/status"
    static let fetchIdentityVerificationMetadata: String = proxyEndPoint + "/api/user/identity/metadata"
    static let healthCheck: String = proxyEndPoint + "/api/health"
    static let sendLikeToVoiceChat: String = proxyEndPoint + "/api/voice_chat/send_like"
    static let joinVoiceChat: String = proxyEndPoint + "/api/voice_chat/join_event"
    static let leaveVoiceChat: String = proxyEndPoint + "/api/voice_chat/leave_event"
    
    static let supabaseStorageBaseEndPoint: String = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_STORAGE_BASE_URL") as! String
    static let reusableEndPoint: String = supabaseStorageBaseEndPoint + "/storage/v1/upload/resumable"
}

// MARK: - MeetingPlan
extension String {
    static let entertainment: String = "🎬 エンタメ・鑑賞"
    static let food: String = "🥢 グルメ"
    static let outdoor: String = "🛝 アウトドア・散歩"
    static let activity: String = "🎢 アクティビティ"
}

// MARK: - Supabase Table and Storage
extension String {
    static let genreType: String = "GenreType"
    
    func b64() -> Self {
        return Data(self.utf8).base64EncodedString()
    }
    
    func containsSubsequence(subString: String) -> Bool {
        if subString.isEmpty { return true }
        
        var iterator = subString.makeIterator()
        var currentCharacter = iterator.next()
        
        for char in self {
            if char == currentCharacter {
                currentCharacter = iterator.next()
                if currentCharacter == nil {
                    return true
                }
            }
        }
        
        return false
    }
}

