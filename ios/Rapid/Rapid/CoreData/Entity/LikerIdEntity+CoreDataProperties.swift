//
//  LikerIdEntity+CoreDataProperties.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/10/30.
//
//

public import Foundation
public import CoreData


public typealias LikerIdEntityCoreDataPropertiesSet = NSSet

extension LikerIdEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LikerIdEntity> {
        return NSFetchRequest<LikerIdEntity>(entityName: "LikerIdEntity")
    }

    @NSManaged public var likerId: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?

}

extension LikerIdEntity : Identifiable {

}
