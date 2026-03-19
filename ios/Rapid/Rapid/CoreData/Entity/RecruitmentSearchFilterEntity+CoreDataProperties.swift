//
//  RecruitmentSearchFilterEntity+CoreDataProperties.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/25.
//
//

public import Foundation
public import CoreData


public typealias RecruitmentSearchFilterEntityCoreDataPropertiesSet = NSSet

extension RecruitmentSearchFilterEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecruitmentSearchFilterEntity> {
        return NSFetchRequest<RecruitmentSearchFilterEntity>(entityName: "RecruitmentSearchFilterEntity")
    }

    @NSManaged public var fromAge: Int16
    @NSManaged public var toAge: Int16
    @NSManaged public var residenceRadius: Double
    @NSManaged public var locationKeyword: String?
    @NSManaged public var lastLoginSort: Bool

}

extension RecruitmentSearchFilterEntity : Identifiable {

}
