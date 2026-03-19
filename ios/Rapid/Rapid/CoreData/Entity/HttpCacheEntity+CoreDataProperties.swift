//
//  HttpCacheEntity+CoreDataProperties.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/09/19.
//
//

public import Foundation
public import CoreData


public typealias HttpCacheEntityCoreDataPropertiesSet = NSSet

extension HttpCacheEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HttpCacheEntity> {
        return NSFetchRequest<HttpCacheEntity>(entityName: "HttpCacheEntity")
    }

    @NSManaged public var expiresAt: Date?
    @NSManaged public var data: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var key: String?

}

extension HttpCacheEntity : Identifiable {

}
