//
//  DataModel+CoreDataProperties.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/10.
//
//

import Foundation
import CoreData


extension DataModel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DataModel> {
        return NSFetchRequest<DataModel>(entityName: "DataModel")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var data: Data?
    @NSManaged public var typeName: String?

}

extension DataModel : Identifiable {

}
