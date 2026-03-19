//
//  Notification + Extention.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/08.
//

import Foundation

extension Notification.Name {
    // MARK: - moving root view
    static let pushRootViewNotification = Notification.Name("pushRootViewNotification")
    static let popRootViewNotification = Notification.Name("popRootViewNotification")
    static let loginErrorNotification = Notification.Name("loginErrorNotification")
    static let sendUserModelNotification = Notification.Name("sendUserModelNotification")
    
    // MARK: - location update
    static let sendLocationNotification = Notification.Name("sendLocationNotification")
    
    // MARK: - GMSMapView
    static let updateMapCenterLocationNotification = Notification.Name("updateMapCenterLocationNotification")
    
    // MARK: - Location Search Filter
    static let deleteSelectedGenreCodeNotification = Notification.Name("deleteSelectedGenreCodeNotification")
    
    // MARK: - Bottom Sheet
    static let updateBottomSheetNotification = Notification.Name("updateBottomSheetNotification")
    
    // MARK: - CoreData
    static let logMessageNotification = Notification.Name("logMessageNotification")
    
    // MARK: - AppDelegate
    static let likedNotification = Notification.Name("likedNotification")
    
    // MARK: - Subscribe Chat Message
    static let receiveMessageNotification = Notification.Name("receiveMessageNotification")
    static let insertMessageNotification = Notification.Name("insertMessageNotification")
    static let sendChatRoomNotification = Notification.Name("sendChatRoomNotification")
    static let sendChatMessageNotification = Notification.Name("sendChatMessageNotification")
    static let uploadImageMessageNotification = Notification.Name("uploadImageMessageNotification")
    static let showReceiveMessageNotification = Notification.Name("showReceiveMessageNotification")
    static let matchingNotification = Notification.Name("matchingNotification")
    
    // MARK: - Video Chat
    static let receiveVideoSignalNotification = Notification.Name("receiveVideoSignalNotification")
    static let callAlertNotification = Notification.Name("callAlertNotification")
    static let returnGreetMessageNotification = Notification.Name("returnGreetMessageNotification")
    static let toggleShowVideoViewNotification = Notification.Name("toggleShowVideoViewNotification")
    
    // MARK: - CallKit
    static let performAnswerCallNotification = Notification.Name("performAnswerCallNotification")
    static let performEndCallNotification = Notification.Name("performEndCallNotification")
    
    // MARK: - Review message
    static let receiveProfileImageReviewNotification = Notification.Name("receiveProfileImageReviewNotification")
    
    // MARK: - Introduction moderate result message
    static let receiveIntroductionModerateNotification = Notification.Name("receiveIntroductionModerateNotification")
    
    // MARK: - Identity verification result message
    static let receiveIdentityVerificationNotification = Notification.Name("receiveIdentityVerificationNotification")
    
    // MARK: - Subscription
    static let consumptionTotalPoint = Notification.Name("consumptionTotalPoint")
    
    // MARK: - Maintenance
    static let receiveMaintenanceNotification = Notification.Name("receiveMaintenanceNotification")
    
    // MARK: - VoiceChat
    static let receiveVoiceChatStartedNotification = Notification.Name("receiveVoiceChatStartedNotification")
    static let receiveVoiceChatMatchedNotification = Notification.Name("receiveVoiceChatMatchedNotification")
}
