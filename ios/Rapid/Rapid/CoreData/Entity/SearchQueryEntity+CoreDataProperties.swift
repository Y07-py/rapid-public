//
//  SearchQueryEntity+CoreDataProperties.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/16.
//
//

public import Foundation
public import CoreData


public typealias SearchQueryEntityCoreDataPropertiesSet = NSSet

extension SearchQueryEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SearchQueryEntity> {
        return NSFetchRequest<SearchQueryEntity>(entityName: "SearchQueryEntity")
    }

    @NSManaged public var query: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?

}

extension SearchQueryEntity : Identifiable {

}
