//
//  ChatRoomNotificationSettingEntity+CoreDataProperties.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/03/03.
//
//

public import Foundation
public import CoreData


public typealias ChatRoomNotificationSettingEntityCoreDataPropertiesSet = NSSet

extension ChatRoomNotificationSettingEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChatRoomNotificationSettingEntity> {
        return NSFetchRequest<ChatRoomNotificationSettingEntity>(entityName: "ChatRoomNotificationSettingEntity")
    }

    @NSManaged public var roomId: UUID?
    @NSManaged public var isMessageNotification: Bool

}

extension ChatRoomNotificationSettingEntity : Identifiable {

}
