//
//  CoreDataStack.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/10.
//

import Foundation
import SwiftUI
import CoreData

public class CoreDataStack: ObservableObject {
    static let shared = CoreDataStack()
    
    private let logger = Logger.shared
    private var dataCache = NSCache<NSString, NSData>()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "CoreData")
        
        container.loadPersistentStores { _, error in
            if let error {
                self.logger.error("❌ Failed to load persistent stores: \(error.localizedDescription).")
                fatalError("Failed to load persistent stores: \(error.localizedDescription)")
            }
        }
        
        return container
    }()
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(logDisplay(notification:)),
            name: .logMessageNotification,
            object: nil)
    }
    
    @Sendable
    public func save(context: NSManagedObjectContext) {
        // When saving data to Core Data, this function conforms to @Sendable,
        // but since the logger does not conform to this protocol, logging is  avoided within this function.
        guard context.hasChanges else { return }
        
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.perform {
            do {
                try context.save()
                NotificationCenter.default.post(
                    name: .logMessageNotification,
                    object: nil,
                    userInfo: ["message": (LogLevel.info, "✅ Successfully saved in context.")])
            } catch let error {
                let nsError = error as NSError
                NotificationCenter.default.post(
                    name: .logMessageNotification,
                    object: nil,
                    userInfo: ["message": (LogLevel.error, "❌ Failed to saved in context: \(nsError)")])
                if let detailed = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
                    let detailedString = detailed.map { "\($0.domain) \($0.code): \($0.userInfo)" }.joined(separator: "\n")
                    NotificationCenter.default.post(
                        name: .logMessageNotification,
                        object: nil,
                        userInfo: ["message": (LogLevel.error, "❌ Failed to saved in context \(detailedString)")])
                } else {
                    NotificationCenter.default.post(
                        name: .logMessageNotification,
                        object: nil,
                        userInfo: ["message": (LogLevel.error, "❌ Failed to saved in context: \(nsError.userInfo)")])
                }
            }
        }
    }
    
    public func save<T: Codable>(_ object: T) {
        do {
            // check whether the target data is stored in the cache.
            let jsonData = try JSONEncoder().encode(object)
            dataCache.setObject(jsonData as NSData, forKey: String(describing: type(of: object.self)) as NSString)
            
            // remove dupliactes item.
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "DataModel")
            fetchRequest.predicate = NSPredicate(format: "typeName == %@", String(describing: type(of: object.self)))
            let duplicates = try persistentContainer.viewContext.fetch(fetchRequest)
            for duplicate in duplicates {
                persistentContainer.viewContext.delete(duplicate as! NSManagedObject)
            }
            
            let dataModel = DataModel(context: persistentContainer.viewContext)
            dataModel.data = jsonData
            dataModel.createdAt = Date()
            dataModel.typeName = String(describing: object.self)
    
            save(context: mainContext)
        } catch let error {
            logger.error("❌ Failed to save object: \(error.localizedDescription)")
        }
    }
    
    public func save(likerModel: LikerUserId) {
        
        // save with main context. Because this save method will usded in ViewModel.
        let context = self.mainContext
        let likerIdEntity = LikerIdEntity(context: context)
        likerIdEntity.id = likerModel.id
        likerIdEntity.likerId = likerModel.likerId
        likerIdEntity.createdAt = likerModel.createdAt
        self.save(context: context)
    }
    
    public func fetchLikerIds() -> [LikerIdEntity] {
        // this functions will user in main thread. so using persitent container view context.
        
        do {
            let context = self.mainContext
            let fetchRequest = NSFetchRequest<LikerIdEntity>(entityName: "LikerIdEntity")
            return try context.fetch(fetchRequest)
        } catch let error {
            logger.error("❌ Failed to fetch LikerIdEntity: \(error.localizedDescription)")
            return []
        }
    }
    
    public func fetchMatchIds() -> [MatchEntity] {
        do {
            let context = self.mainContext
            let fetchRequest = NSFetchRequest<MatchEntity>(entityName: "MatchEntity")
            return try context.fetch(fetchRequest)
        } catch let error {
            logger.error("❌ Failed to fetch MatchIdEntity: \(error.localizedDescription)")
            return []
        }
    }
    
    public func fetch<T: Codable>(_ objectName: String) -> T? {
        do {
            // Check the data is stored in the cache and return it if it exists.
            if let cacheData = dataCache.object(forKey: objectName as NSString) {
                return try JSONDecoder().decode(T.self, from: cacheData as Data)
            }
            
            let fetchRequest = NSFetchRequest<DataModel>(entityName: "DataModel")
            fetchRequest.predicate = NSPredicate(format: "typeName == %@", objectName)
            let results = try persistentContainer.viewContext.fetch(fetchRequest)
            guard let result = results.first else { return nil }
            
            // if inmemory does not have object, resave in memory.
            self.dataCache.setObject(result.data! as NSData, forKey: objectName as NSString)
            
            return try JSONDecoder().decode(T.self, from: result.data!)
        } catch let error {
            logger.warning("⚠️ Failed to ferch \(objectName). : \(error.localizedDescription)")
            return nil
        }
    }
    
    public func fetchHttpCache<T: Codable>(context: NSManagedObjectContext, key: String) throws -> T? {
        // Check the data is stored in the cache and return it if it exists.
        if let cacheData = dataCache.object(forKey: key as NSString) {
            return try JSONDecoder().decode(T.self, from: cacheData as Data)
        }
        
        let fetchRequest = NSFetchRequest<HttpCacheEntity>(entityName: "HttpCacheEntity")
        fetchRequest.predicate = NSPredicate(format: "key == %@", key)
        let results = try context.fetch(fetchRequest)
        guard let result = results.first else { return nil }
        
        // if inmemory does not have object, resave in memory.
        dataCache.setObject(result.data! as NSData, forKey: key as NSString)
        
        return try JSONDecoder().decode(T.self, from: result.data!)
    }
    
    public func delete(item: DataModel) {
        persistentContainer.viewContext.delete(item)
        save(context: mainContext)
    }
    
    @objc private func logDisplay(notification: NSNotification) {
        if let userinfo = notification.userInfo as? [String: (LogLevel, String)] {
            guard let logLevel = userinfo["message"]?.0,
                  let detail = userinfo["message"]?.1 else { return }
            
            switch logLevel {
            case .info:
                logger.info(detail)
            case .error:
                logger.error(detail)
            case .debug:
                logger.debug(detail)
            case .critical:
                logger.critical(detail)
            case .verbose:
                logger.verbose(detail)
            case .warning:
                logger.warning(detail)
            }
        }
    }
}

// MARK: Http Cache
extension CoreDataStack {
    public func getCache(_ key: String) -> HttpCacheEntity? {
        /// This function is a method for reading cache data for Http requests. Data stoerd in memory
        ///  is managed by the `HttpCacheManager`
        do {
            let fetchRequest = NSFetchRequest<HttpCacheEntity>(entityName: "HttpCacheEntity")
            fetchRequest.predicate = NSPredicate(format: "key == %@", key)
            let results = try persistentContainer.viewContext.fetch(fetchRequest)
            guard let result = results.first else { return nil }
            
            return result
        } catch let error {
            logger.warning("⚠️ Faile to fetch \(key).: \(error.localizedDescription)")
            return nil
        }
    }
    
    public func deleteHttpCache() throws {
        /// This method for deleting cache data that has passed its expires at time. Even if multiple items are targeted for deletion
        /// parallel processin is not performed. Instead, sequential processing is used to prevent data conflicts
        
        let now = Date.now
        let context = self.backgroundContext
        
        let fetchRequest = NSFetchRequest<HttpCacheEntity>(entityName: "HttpCacheEntity")
        fetchRequest.predicate = NSPredicate(format: "expiresAt < %@", now as NSDate)
        let results = try context.fetch(fetchRequest)
        
        try results.forEach { entity in
            context.delete(entity)
            if context.hasChanges {
                try context.save()
            }
        }
    }
}

// MARK: chat message
extension CoreDataStack {
    public func saveChatSubscription(_ chatRoom: ChatRoom) throws {
        let context = self.backgroundContext
        let subscriptionEntity = SupabaseSubscriptionEntity(context: context)
        subscriptionEntity.channelId = chatRoom.id
        subscriptionEntity.createdAt = chatRoom.createdAt
        self.save(context: context)
    }
    
    public func fetchChatSubscription() throws -> [SupabaseSubscriptionEntity] {
        let context = self.mainContext
        let fetchRequest = NSFetchRequest<SupabaseSubscriptionEntity>(entityName: "SupabaseSubscriptionEntity")
        
        return try context.fetch(fetchRequest)
    }
}

// MARK: switch viewContext
extension CoreDataStack {
    public var mainContext: NSManagedObjectContext {
        self.persistentContainer.viewContext
    }
    
    public var backgroundContext: NSManagedObjectContext {
        self.persistentContainer.newBackgroundContext()
    }
}

// MARK: - Search Query Queue
extension CoreDataStack {
    public func pushSearchQuery(query: String) -> LocationSearchQuery? {
        let viewContext = self.persistentContainer.viewContext
        
        // Push search query
        let searchQueryEntity = SearchQueryEntity(context: viewContext)
        searchQueryEntity.id = .init()
        searchQueryEntity.query = query
        searchQueryEntity.createdAt = .now
        
        do {
            let fetchRequest = NSFetchRequest<SearchQueryEntity>(entityName: "SearchQueryEntity")
            fetchRequest.sortDescriptors = [.init(key: "createdAt", ascending: true)]
            /// Delete oldest query if search queries limit exceeded 10
            var searchQueries = try viewContext.fetch(fetchRequest)
            if searchQueries.count > 10 {
                let oldestQuery = searchQueries.removeFirst()
                viewContext.delete(oldestQuery)
            }
            self.save(context: viewContext)
            
            return LocationSearchQuery(id: searchQueryEntity.id!, query: searchQueryEntity.query!, createdAt: searchQueryEntity.createdAt!)
        } catch let error {
            self.logger.error("❌ Failed to fetch request. \(error.localizedDescription)")
        }
        
        return nil
    }
    
    public func getSearchQueries() -> [LocationSearchQuery] {
        do {
            let viewContext = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<SearchQueryEntity>(entityName: "SearchQueryEntity")
            fetchRequest.sortDescriptors = [.init(key: "createdAt", ascending: false)]
            let entities = try viewContext.fetch(fetchRequest)
            let queries: [LocationSearchQuery] = entities.compactMap({ entity in
                guard let id = entity.id, let query = entity.query, let createdAt = entity.createdAt else { return nil }
                return LocationSearchQuery(id: id, query: query, createdAt: createdAt)
            })
            return queries
        } catch let error {
            self.logger.error("❌ Failed to get search queries: \(error.localizedDescription)")
            return []
        }
    }
    
    public func deleteSearchQuery(query: LocationSearchQuery) {
        do {
            let viewContext = self.persistentContainer.viewContext
            let request = NSFetchRequest<SearchQueryEntity>(entityName: "SearchQueryEntity")
            request.predicate = NSPredicate(format: "id == %@", query.id as NSUUID)
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
            }
            self.save(context: viewContext)
        } catch let error {
            self.logger.error("❌ Failed to delete search query: \(error.localizedDescription)")
        }
    }
    
    public func saveRecruitmentFilter(filter: FetchRecruitmentRequestParamaterWithFilter) {
        let viewContext = self.persistentContainer.viewContext
        let entity = RecruitmentSearchFilterEntity(context: viewContext)
        entity.fromAge = filter.ageRange?.fromAge as? Int16 ?? .zero
        entity.toAge = filter.ageRange?.toAge as? Int16 ?? .zero
        entity.locationKeyword = filter.locationKeyword
        entity.residenceRadius = filter.residenceRadius ?? .zero
        entity.lastLoginSort = filter.sortLogin
        
        do {
            let request = NSFetchRequest<RecruitmentSearchFilterEntity>(entityName: "RecruitmentSearchFilterEntity")
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
            }
            self.save(context: viewContext)
        } catch let error {
            self.logger.error("❌ Failed to save search filter entity: \(error.localizedDescription)")
        }
    }
    
    public func fetchRecruitmentFilter() -> FetchRecruitmentRequestParamaterWithFilter? {
        let viewContext = self.persistentContainer.viewContext
        let request = NSFetchRequest<RecruitmentSearchFilterEntity>(entityName: "RecruitmentSearchFilterEntity")
        
        do {
            if let entity = try viewContext.fetch(request).first {
                let ageRange = FetchRecruitmentRequestParamaterWithAgeRange(fromAge: Int(entity.fromAge), toAge: Int(entity.toAge))
                let filter = FetchRecruitmentRequestParamaterWithFilter(
                    ageRange: ageRange,
                    residenceRadius: entity.residenceRadius,
                    locationKeyword: entity.locationKeyword ,
                    sortLogin: entity.lastLoginSort
                )
                return filter
            }
        } catch let error {
            self.logger.error("❌ Failed to fetch search filter entity: \(error.localizedDescription)")
        }
        return nil
    }
    
    // MARK: - Chat Room Setting
    public func upsertChatRoomMessageNotification(roomId: UUID, isOnMessageNotification: Bool) throws {
        let viewContext = self.persistentContainer.viewContext
        let request = NSFetchRequest<ChatRoomNotificationSettingEntity>(entityName: "ChatRoomNotificationSettingEntity")
        request.predicate = NSPredicate(format: "roomId == %@", roomId as NSUUID)
        
        if let entity = try viewContext.fetch(request).first {
            entity.isMessageNotification = isOnMessageNotification
        } else {
            let messageNotificationEntity = ChatRoomNotificationSettingEntity(context: viewContext)
            messageNotificationEntity.roomId = roomId
            messageNotificationEntity.isMessageNotification = isOnMessageNotification
        }
        
        self.save(context: viewContext)
    }
    
    public func fetchChatRoomNotificationSetting(roomId: UUID) -> ChatRoomNotificationSettingEntity? {
        let viewContext = self.persistentContainer.viewContext
        let request = NSFetchRequest<ChatRoomNotificationSettingEntity>(entityName: "ChatRoomNotificationSettingEntity")
        request.predicate = NSPredicate(format: "roomId == %@", roomId as NSUUID)
        
        do {
            return try viewContext.fetch(request).first
        } catch let error {
            self.logger.error("❌ Failed to fetch notification setting: \(error.localizedDescription)")
            return nil
        }
    }
}
