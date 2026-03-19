//
//  SupabaseSubscriptionEntity+CoreDataProperties.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/04.
//
//

public import Foundation
public import CoreData


public typealias SupabaseSubscriptionEntityCoreDataPropertiesSet = NSSet

extension SupabaseSubscriptionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SupabaseSubscriptionEntity> {
        return NSFetchRequest<SupabaseSubscriptionEntity>(entityName: "SupabaseSubscriptionEntity")
    }

    @NSManaged public var channelId: UUID?
    @NSManaged public var createdAt: Date?

}

extension SupabaseSubscriptionEntity : Identifiable {

}
