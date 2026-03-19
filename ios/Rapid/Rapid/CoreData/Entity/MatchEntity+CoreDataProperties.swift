//
//  MatchEntity+CoreDataProperties.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/01.
//
//

public import Foundation
public import CoreData


public typealias MatchEntityCoreDataPropertiesSet = NSSet

extension MatchEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MatchEntity> {
        return NSFetchRequest<MatchEntity>(entityName: "MatchEntity")
    }

    @NSManaged public var opponentId: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var chatId: UUID?

}

extension MatchEntity : Identifiable {

}
