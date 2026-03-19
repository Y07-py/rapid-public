//
//  ChatRoomViewModel.swift
//  Rapid
//
//  Created by Claude on 2026/02/10.
//

import Foundation
import SwiftUI
import Supabase

fileprivate final class RoomCacheWrapper<T>: NSObject {
    let value: T

    init(value: T) {
        self.value = value
    }
}

fileprivate struct ImageMessageURL {
    var url: URL
    var expiresAt: Date
}

public class ChatRoomViewModel: ObservableObject {
    private let supabase = SupabaseManager.shared
    private let logger = Logger.shared
    private var http: HttpClient = {
        let client = HttpClient(auth: HttpSupabaseAuthenticator(), retryPolicy: .exponentialBackoff(3, 4.5))
        return client
    }()
    private let coreData = CoreDataStack.shared

    let chatViewModel: ChatViewModel

    @Published var messageOffset: Int = 0
    @Published var mediaImages: [ChatMessage] = []
    @Published var talkCount: Int = 0
    
    // Chat Room Setting
    @Published var isOnMessageNotification: Bool = true
    @Published var isReported: Bool = false
    
    private var processedMessageIds: Set<UUID> = []

    private let imageMessageCache: NSCache<NSString, RoomCacheWrapper<ImageMessageURL>> = .init()

    public init(chatViewModel: ChatViewModel) {
        self.chatViewModel = chatViewModel
        
        Task { @MainActor in
            self.enterChatRoom()
        }
        
        NotificationCenter.default.addObserver(forName: .insertMessageNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            if let action = notification.userInfo?["action"] as? InsertAction {
                Task { @MainActor in
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .tolerantISO8601
                        let message = try action.decodeRecord(as: ChatMessage.self, decoder: decoder)
                        
                        guard let selectedRoom = self.chatViewModel.selectedChatRoom,
                              selectedRoom.chatRoom.id == message.roomId else { return }
                        
                        self.updateLocalTalkCount(with: message)
                    } catch {
                        self.logger.error("❌ Failed to decode message in talkCount update: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

extension ChatRoomViewModel {
    @MainActor
    private func enterChatRoom() {
        guard let selectedChatRoom = self.chatViewModel.selectedChatRoom else { return }
        self.fetchNotificationSetting(roomId: selectedChatRoom.chatRoom.id)
        self.talkCount = selectedChatRoom.chatRoom.talkCount ?? 0
        self.isReported = selectedChatRoom.isReported
        
        if selectedChatRoom.unReadCount > 0 {
            self.chatViewModel.unreadMessageCount -= selectedChatRoom.unReadCount
            guard let chatRoom = self.chatViewModel.chatRooms.first(where: { $0.value.chatRoom.id == selectedChatRoom.chatRoom.id })?.value else { return }
            self.chatViewModel.chatRooms[chatRoom.chatRoom.id]?.unReadCount = 0

            Task {
                do {
                    try await self.supabase.insertChatRoomLog(roomId: selectedChatRoom.chatRoom.id)
                    try await self.supabase.checkChatRoomMessages(roomId: selectedChatRoom.chatRoom.id)
                } catch let error {
                    self.logger.error("❌ Failed to insert chat room log: \(error.localizedDescription)")
                }
            }
        }
        
        Task {
            // Update image message context
            let messages = await self.updateImageMesageContent(chatRoom: selectedChatRoom)
            await MainActor.run {
                self.mediaImages = messages.filter({ $0.contextType == "image" })
                self.chatViewModel.selectedChatRoom?.messages = messages
            }
        }
    }
    
    private func updateImageMesageContent(chatRoom: ChatRoomWithRecruitment) async -> [ChatMessage] {
        var messages = chatRoom.messages
        await withTaskGroup(of: (Int, String)?.self) { group in
            for (i, message) in messages.enumerated() {
                guard message.contextType == "image" else { continue }
                group.addTask {
                    guard let url = await message.buildImageMessageURL() else { return nil }
                    return (i, url.absoluteString)
                }
            }
            
            for await item in group {
                guard let item = item else { continue }
                messages[item.0].context = item.1
            }
        }
        return messages
    }

    @MainActor
    public func sendMessage(text: String? = nil, images: [UIImage]? = nil, completion: @escaping () -> Void) {
        Task {
            guard let selectedChatRoom = self.chatViewModel.selectedChatRoom,
                  let session = await self.supabase.getSession() else { return }

            do {
                if let text = text {
                    try await self.sendTextMessage(
                        toUserId: selectedChatRoom.roomUser.user.id,
                        roomId: selectedChatRoom.chatRoom.id,
                        session: session,
                        text: text,
                        completion: completion
                    )
                } else if let images = images {
                    try await self.sendImageMessage(
                        toUserId: selectedChatRoom.roomUser.user.id,
                        roomId: selectedChatRoom.chatRoom.id,
                        session: session,
                        images: images,
                        completion: completion
                    )
                }
            } catch let error {
                self.logger.error("❌ Failed to send message: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func sendTextMessage(
        toUserId: UUID,
        roomId: UUID,
        session: Session,
        text: String,
        completion: @escaping () -> Void
    ) async throws {
        let chatMessage = ChatMessage(
            toUserId: toUserId,
            fromUserId: session.user.id,
            roomId: roomId,
            context: text,
            contextType: "text",
            createdAt: .now,
            updatedAt: .now,
            checked: false
        )
        completion()
        self.chatViewModel.selectedChatRoom?.messages.append(chatMessage)
        self.updateLocalTalkCount(with: chatMessage)

        let response = try await self.http.post(url: .sendMessage, content: chatMessage)
        if response.ok {
            self.chatViewModel.chatRooms[roomId]?.messages.append(chatMessage)
            self.chatViewModel.chatRooms[roomId]?.lastMessage = chatMessage.context
            
            if let updatedRoom = await self.fetchChatRoom(roomId: roomId.uuidString) {
                let count = updatedRoom.talkCount ?? 0
                self.talkCount = count
                self.chatViewModel.chatRooms[roomId]?.chatRoom.talkCount = count
                self.chatViewModel.selectedChatRoom?.chatRoom.talkCount = count
            }
        }
    }
    
    @MainActor
    private func sendImageMessage(
        toUserId: UUID,
        roomId: UUID,
        session: Session,
        images: [UIImage],
        completion: @escaping () -> Void
    ) async throws {
        for image in images {
            let chatMessageId = UUID()
            let storagePath = "\(chatMessageId.uuidString.lowercased())"
            let chatMessage = ChatMessage(
                id: chatMessageId,
                toUserId: toUserId,
                fromUserId: session.user.id,
                roomId: roomId,
                context: storagePath,
                contextType: MessageContentType.image.rawValue,
                createdAt: .now,
                updatedAt: .now,
                checked: false,
                image: image
            )

            self.chatViewModel.selectedChatRoom?.messages.append(chatMessage)
            self.updateLocalTalkCount(with: chatMessage)

            let stream = try await self.supabase.uploadMessageImage(
                roomId: roomId,
                messageId: chatMessage.id,
                image: image
            )
            for try await _ in stream {}

            let response = try await self.http.post(url: .sendMessage, content: chatMessage)
            if response.ok {
                self.chatViewModel.chatRooms[roomId]?.messages.append(chatMessage)
                self.chatViewModel.chatRooms[roomId]?.lastMessage = "画像を送信しました。"
                
                if let updatedRoom = await self.fetchChatRoom(roomId: roomId.uuidString) {
                    let count = updatedRoom.talkCount ?? 0
                    self.talkCount = count
                    self.chatViewModel.chatRooms[roomId]?.chatRoom.talkCount = count
                    self.chatViewModel.selectedChatRoom?.chatRoom.talkCount = count
                }
                
                completion()
            }
        }
    }

    @MainActor
    public func getImageMessageURL(roomId: UUID, messageId: UUID) async -> URL? {
        if let cacheURL = self.imageMessageCache.object(forKey: messageId.uuidString.lowercased() as NSString) {
            if cacheURL.value.expiresAt < Date.now {
                return cacheURL.value.url
            }
        }

        do {
            let imageURL = try await self.supabase.buildPresignedURLForMessageImage(roomId: roomId, messageId: messageId)
            let expiresAt = Date.now.addingTimeInterval(60 * 60 * 24 * 6)
            let imageMessageURL = ImageMessageURL(url: imageURL, expiresAt: expiresAt)
            self.imageMessageCache.setObject(RoomCacheWrapper(value: imageMessageURL), forKey: messageId.uuidString.lowercased() as NSString)
            return imageURL
        } catch let error {
            self.logger.error("❌ Failed to get image URL from storage: \(error.localizedDescription)")
        }

        return nil
    }

    @MainActor
    public func reloadMessages(limit: Int = 100) {
        guard let selectedChatRoom = self.chatViewModel.selectedChatRoom else { return }

        Task { @MainActor in
            do {
                let offset = self.messageOffset + limit - 1
                let messages = try await self.supabase.selectChatMessages(roomId: selectedChatRoom.chatRoom.id, offset: offset, limit: limit)
                guard !messages.isEmpty else { return }
                self.chatViewModel.selectedChatRoom?.messages.insert(contentsOf: messages, at: 0)
                self.messageOffset = offset
            } catch let error {
                self.logger.error("❌ Failed to reload message: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    public func blockingUser(completion: @escaping (UUID) -> Void) {
        Task {
            guard let selectedChatRoom = self.chatViewModel.selectedChatRoom,
                  let session = await self.supabase.getSession() else { return }
            
            let blockedUserId = selectedChatRoom.roomUser.user.id
            let userId = session.user.id
            let blockedAt = Date.now
            let payload = BlockedUser(userId: userId, blockedUserId: blockedUserId, blockedAt: blockedAt)
            
            do {
                completion(selectedChatRoom.chatRoom.id)
                let _ = try await self.http.post(url: .blockingUser, content: payload)
            } catch let error {
                if let error = error as? HttpError {
                    self.logger.error("❌ Failed to block user: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func fetchChatRoom(roomId: String) async -> ChatRoom? {
        do {
            guard let roomId = UUID(uuidString: roomId) else { return nil }
            let room = try await self.supabase.selectChatRoom(roomId: roomId)
            return room
        } catch let error {
            self.logger.error("❌ Failed to fetch chat room: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Place detail & nearby transports
extension ChatRoomViewModel {
    public func fetchPlaceDetail(
        _ wrapper: GooglePlacesSearchPlaceWrapper,
        fieldMask: [GooglePlaceFieldMask]
    ) async -> GooglePlacesSearchPlaceWrapper? {
        guard let placeId = wrapper.place?.id else { return nil }
        let fieldMaskJoined = fieldMask.map({ $0.rawValue }).joined(separator: ",")
        let param = GooglePlacesPlaceDetailBodyParamater(fieldMask: fieldMaskJoined, placeIds: [placeId], languageCode: "ja")

        do {
            let resp = try await http.post(url: .getPlaceDetails, content: param)
            let places: [GooglePlacesSearchResponsePlace] = try resp.decode()
            if let place = places.first {
                return GooglePlacesSearchPlaceWrapper(place: place)
            }
        } catch {
            logger.error("Failed to fetch place detail: \(error.localizedDescription)")
        }
        return nil
    }

    public func searchNearbyTransports(latitude: Double, longitude: Double) async -> [GooglePlacesTransport] {
        let placeTypes: [GooglePlaceType] = [.trainStation, .subwayStation, .busStation, .airport, .ferryTerminal]
        let fieldMask: [GooglePlaceFieldMask] = [.id, .displayName, .location, .types]
        let fieldMaskJoined = fieldMask.map({ "places.\($0.rawValue)" }).joined(separator: ",")

        let circle = LocationCircle(latitude: latitude, longitude: longitude, radius: 1000)
        let restriction = LocationRestriction(circle: circle)
        let body = GooglePlacesNearbySearchBodyParamater(
            includedTypes: placeTypes,
            maxResultCount: 10,
            languageCode: "ja",
            rankPreference: "DISTANCE",
            locationRestriction: restriction
        )
        let clientParam = PlaceSearchClientParamater(latitude: latitude, longitude: longitude, zoom: 15, windowSize: .init(width: 390, height: 844), scale: 3.0)
        let param = GooglePlacesNearbySearchParamater(requestParamater: body, fieldMask: fieldMaskJoined, clientParamater: clientParam)

        do {
            let response = try await http.post(url: .searchNearbyTransports, content: param)
            let places: [GooglePlacesSearchResponsePlace] = try response.decode()
            return places.compactMap { place in
                guard let lat = place.location?.latitude,
                      let lon = place.location?.longitude else { return nil }
                let d = computeDistance(lat1: latitude, lon1: longitude, lat2: lat, lon2: lon)
                return GooglePlacesTransport(l2Distance: d, place: place)
            }
        } catch {
            logger.error("Failed to search nearby transports: \(error.localizedDescription)")
        }
        return []
    }

    private func computeDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let rLat1 = lat1 * .pi / 180.0
        let rLon1 = lon1 * .pi / 180.0
        let rLat2 = lat2 * .pi / 180.0
        let rLon2 = lon2 * .pi / 180.0

        let a: Double = .GRS80_EQUATION_RADIUS
        let b: Double = .GRS80_SHORT_RADIUS

        let e2 = (pow(a, 2) - pow(b, 2)) / pow(a, 2)

        let dLat = rLat1 - rLat2
        let dLon = rLon1 - rLon2
        let latAve = (rLat1 + rLat2) / 2.0

        let sinLat = sin(latAve)
        let w = sqrt(1.0 - e2 * pow(sinLat, 2))

        let m = a * (1.0 - e2) / pow(w, 3)
        let n = a / w

        let d = sqrt(pow(dLat * m, 2) + pow(dLon * n * cos(latAve), 2))

        return d
    }
    
    @MainActor
    private func fetchNotificationSetting(roomId: UUID) {
        if let setting = self.coreData.fetchChatRoomNotificationSetting(roomId: roomId) {
            self.isOnMessageNotification = setting.isMessageNotification
        }
    }

    @MainActor
    public func updateMessageNotification() {
        Task {
            do {
                guard let selectedChatRoom = self.chatViewModel.selectedChatRoom else { return }
                try self.coreData.upsertChatRoomMessageNotification(roomId: selectedChatRoom.chatRoom.id,
                                                                    isOnMessageNotification: isOnMessageNotification)
                try await self.supabase.upsertChatRoomMesageNotification(roomId:selectedChatRoom.chatRoom.id,
                                                                         isOn: isOnMessageNotification)
            } catch let error {
                self.logger.error("❌ Failed to update notification setting. \(error.localizedDescription)")
            }
        }
    }

    private func updateLocalTalkCount(with message: ChatMessage) {
        guard !processedMessageIds.contains(message.id) else { return }
        processedMessageIds.insert(message.id)

        guard let messages = self.chatViewModel.selectedChatRoom?.messages else { return }

        let sortedMessages = messages.sorted(by: { $0.createdAt < $1.createdAt })
        let previousMessage = sortedMessages.last(where: { $0.id != message.id && $0.createdAt <= message.createdAt })

        let shouldDecrement: Bool
        if let prev = previousMessage {
            // Different user sends a message -> decrement
            shouldDecrement = prev.fromUserId != message.fromUserId
        } else {
            // First message in the room
            shouldDecrement = true
        }

        if shouldDecrement && self.talkCount > 0 {
            self.talkCount -= 1
            if let roomId = self.chatViewModel.selectedChatRoom?.chatRoom.id {
                self.chatViewModel.chatRooms[roomId]?.chatRoom.talkCount = self.talkCount
                self.chatViewModel.selectedChatRoom?.chatRoom.talkCount = self.talkCount
            }
        }
    }
    
    @MainActor
    public func sendReport(type: String, report: String) {
        
        Task {
            guard let selectedChatRoom = self.chatViewModel.selectedChatRoom,
                  let session = await self.supabase.getSession() else { return }
            
            let chatRoomReport = ChatRoomReport(
                reportUserId: session.user.id,
                targetUserId: selectedChatRoom.roomUser.user.id,
                roomId: selectedChatRoom.chatRoom.id,
                createdAt: .now,
                reportType: type,
                report: report
            )
            
            do {
                let response = try await self.http.post(url: .postChatRoomReport, content: chatRoomReport)
                if response.ok {
                    self.isReported = true
                    if let roomId = selectedChatRoom.chatRoom.id as UUID? {
                        self.chatViewModel.chatRooms[roomId]?.isReported = true
                        self.chatViewModel.selectedChatRoom?.isReported = true
                    }
                }
            } catch let error {
                self.logger.error("❌ Failed to send report: \(error.localizedDescription)")
            }
        }
    }
}
