//
//  ChatViewModel.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/10/30.
//

import Foundation
import SwiftUI
import OrderedCollections
import SDWebImage
import Supabase
import Combine

public class ChatViewModel: ObservableObject {
    private let supabase = SupabaseManager.shared
    private let logger = Logger.shared
    private var http: HttpClient = {
        let client = HttpClient(auth: HttpSupabaseAuthenticator(), retryPolicy: .exponentialBackoff(3, 4.5))
        return client
    }()
    
    private var chatRoomSubscriptions: [UUID: SupabaseSubscription] = [:]
    private var messageDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "MM/dd"
        
        return dateFormatter
    }()
    
    private var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        decoder.dateDecodingStrategy = .formatted(formatter)
        
        return decoder
    }()
    
    private var calendar: Calendar = .current
    
    // Signaling clients for video chat
    private var signalingClients: [UUID: SignalingClient] = [:]
    public var selectedSignalingClient: SignalingClient? = nil
    
    @Published var likers: [Liker] = []
    @Published var selectedUser: RapidUserWithProfile? = nil
    
    @Published var chatRooms: [UUID: ChatRoomWithRecruitment] = [:]
    @Published var selectedChatRoom: ChatRoomWithRecruitment? = nil
    public var sortedChatRooms: [ChatRoomWithRecruitment] {
        chatRooms.values.sorted(by: { $0.chatRoom.createdAt < $1.chatRoom.createdAt })
    }
    @Published var unreadMessageCount: Int = 0
    @Published var unreadLikesCount: Int = 0
    @Published var chatRoomChannels: [UUID: SupabaseSubscription] = [:]
    @Published var currentOffset: Int = 0
    
    @Published var callAlert: Bool = false
    @Published var isShowVideoView: Bool = false
    @Published var callingRole: CallingRole? = nil
    
    @Published var isFetchingChatRooms: Bool = false
    @Published var isShowAlertFetchingChatRooms: Bool = false
    
    @Published var isFetchingLikers: Bool = false
    @Published var isShowAlertFetchingLikers: Bool = false
    
    @Published var isIdentityVerified: Bool = false
    @Published var isSubscribed: Bool = false
    @Published var isWoman: Bool = false
    @Published var isEnableTalk: Bool = false
    @Published var isShowPermissionFlow: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var isDataLoaded = false

    public init() {
        // Monitor network connection and fetch data when established
        NetworkMonitor.shared.$isRealInternetReachable
            .filter { $0 && !self.isDataLoaded }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.startNetworkInitialization()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.addObserver(forName: .receiveMessageNotification, object: nil, queue: .main) { notification in
            if let userId = notification.userInfo?["user_id"] as? String {
                guard self.selectedChatRoom == nil else { return }
                
                Task { @MainActor in
                    do {
                        let rapidUser = try await self.supabase.fetchUserWithProfile(userId: UUID(uuidString: userId)!)
                        
                        NotificationCenter.default.post(name: .showReceiveMessageNotification, object: nil, userInfo: ["user": rapidUser])
                    } catch let error {
                        self.logger.error("❌ Failed to fetch user.: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: .matchingNotification, object: nil, queue: .main) { notification in
            Task { @MainActor in
                await self.fetchChatRooms()
                await self.fetchLikers()
            }
            if let roomId = notification.userInfo?["room_id"] as? String {
                Task {
                    do {
                        let roomId = UUID(uuidString: roomId)!
                        let subscription = try await self.supabase.subscribeChatChannel(roomId: roomId)
                        self.chatRoomSubscriptions[roomId] = subscription
                    } catch let error {
                        self.logger.error("❌ Failed to subscribe chat room channel.: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: .insertMessageNotification, object: nil, queue: .main) { notification in
            if let action = notification.userInfo?["action"] as? InsertAction {
                self.handleInsertAction(action)
            }
        }
        
        NotificationCenter.default.addObserver(forName: .likedNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in
                await self.fetchLikers()
            }
        }
        
        Task { @MainActor in
            await self.checkEnableTalk()
        }
    }
    
    @MainActor
    private func startNetworkInitialization() async {
        await self.fetchLikers()
        await self.fetchChatRooms()
        self.isDataLoaded = true
    }
}

extension ChatViewModel {
    @MainActor
    public func fetchMBTIThumbnailURL(mbti: String) async -> URL? {
        do {
            let folderPath = "thumbnails/\(mbti.lowercased()).png"
            let thumbnailURL: URL = try await supabase.getSinglePresignURLFromStorage(bucket: "mbti", path: folderPath)
            return thumbnailURL
        } catch let error {
            logger.error("❌ Failed to fetch mbti thumbnail url from supabase. \(error.localizedDescription)")
        }
        
        return nil
    }
    
    @MainActor
    private func fetchLikers() async {
        guard let session = await self.supabase.getSession() else { return }
        
        do {
            let blockedUsers = try await supabase.selectBlockedUsers()
            let blockedUserIds = Set(blockedUsers.map { $0.blockedUserId })
            
            let likePairs = try await supabase.selectLikePairs(userId: session.user.id.uuidString.lowercased())
            let filteredLikePairs = likePairs.filter { !blockedUserIds.contains($0.fromUserId) }
            
            let likers: [Liker] = try await withThrowingTaskGroup(of: Liker.self) { [weak self] group in
                guard let self = self else { return [] }
                
                var likers: [Liker] = []
                for like in filteredLikePairs {
                    group.addTask {
                        let userWithProfile = try await self.supabase.fetchUserWithProfile(userId: like.fromUserId)
                        return .init(id: like.id, user: userWithProfile, likedAt: like.likedAt, recruitmentId: like.recruitmentId, isRead: like.isRead)
                    }
                }
                
                for try await liker in group {
                    likers.append(liker)
                }
                
                return likers
            }
            
            self.unreadLikesCount = likers.filter({ !$0.isRead }).count
            self.likers = likers
            self.isFetchingLikers = true
        } catch let error {
            self.logger.error("❌ Failed to fetch like pairs: \(error.localizedDescription)")
            self.isFetchingLikers = true
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.isShowAlertFetchingLikers = true
            }
        }
    }
    
    @MainActor
    public func fetchChatRooms(offset: Int? = nil, limit: Int = 20) async {
        guard let session = await supabase.getSession() else { return }
        let fetchOffset = offset ?? self.currentOffset
        
        do {
            let blockedUsers = try await supabase.selectBlockedUsers()
            let blockedUserIds = Set(blockedUsers.map { $0.blockedUserId })
            
            let rooms = try await supabase.selectChatRooms(userId: session.user.id, offset: fetchOffset, limit: limit)
            let recruitmentIds = rooms.map({ $0.recruitmentId })
            let recruitments = await supabase.selectRecruitments(recruitmentIds: recruitmentIds)
            
            // Fetch reported room IDs from proxy
            var reportedRoomIds: Set<UUID> = []
            do {
                let response = try await self.http.get(url: .getReportedRoomIds)
                if response.ok {
                    let ids: [UUID] = try response.decode()
                    reportedRoomIds = Set(ids)
                }
            } catch {
                self.logger.error("❌ Failed to fetch reported room ids: \(error.localizedDescription)")
            }
            
            if let recruitments = recruitments {
                try await withThrowingTaskGroup(of: (ChatRoomWithRecruitment?, Int, SupabaseSubscription?).self) { group in
                    let fieldMask = GooglePlaceFieldMask.detailFieldMask.map({ $0.rawValue }).joined(separator: ",")
                    
                    for rec in recruitments {
                        guard let places = rec.recruitmentPlaces else { continue }
                        group.addTask {
                            let placeIds = places.compactMap({ $0.placeId })
                            let placeDetail = GooglePlacesPlaceDetailBodyParamater(fieldMask: fieldMask, placeIds: placeIds, languageCode: "ja")

                            let response = try await self.http.post(url: .getPlaceDetails, content: placeDetail)
                            if !response.ok { return (nil, .zero, nil) }
                            
                            // Google places
                            let places: [GooglePlacesSearchResponsePlace] = try response.decode()
                            let placesWrapper = places.map({ GooglePlacesSearchPlaceWrapper(place: $0) })
                            guard let room = rooms.first(where: { $0.recruitmentId == rec.id }) else { return (nil, .zero, nil) }
                            guard let roomUserId = try await self.supabase.selectRoomUser(roomId: room.id, userId: session.user.id) else { return (nil, .zero, nil) }
                            
                            // Filter blocked users
                            if blockedUserIds.contains(roomUserId) {
                                return (nil, .zero, nil)
                            }
                            
                            let roomUserWithProfile = try await self.supabase.fetchUserWithProfile(userId: roomUserId)
                            
                            // Chat messages
                            let messages = try await self.supabase.selectChatMessages(roomId: room.id)
                            var unReadCount = 0
                            var lastMessage = ""
                            if let message = messages.last {
                                if message.contextType == "text" {
                                    lastMessage = message.context
                                } else if message.contextType == "image" {
                                    if message.fromUserId == session.user.id {
                                        lastMessage = "画像を送信しました。"
                                    } else {
                                        lastMessage = "画像が送信されました。"
                                    }
                                }
                                unReadCount = messages.filter({ !$0.checked && $0.toUserId == session.user.id }).count
                            } else {
                                let chatRoomLog = try await self.supabase.selectChatRoomLog(roomId: room.id, userId: session.user.id)
                                if chatRoomLog.count == 0 {
                                    lastMessage = "メッセージを送ってみましょう！"
                                    unReadCount = 1
                                }
                            }
                            
                            // If already subscribe channel, skip it.
                            if self.chatRooms.contains(where: { $0.key == room.id }) {
                                return (nil, 0, nil)
                            }
                            
                            // Subsribe chat room channel.
                            let subscription = try await self.supabase.subscribeChatChannel(roomId: room.id)
                            
                            return (ChatRoomWithRecruitment(
                                chatRoom: room,
                                recruitment: rec,
                                places: placesWrapper,
                                roomUser: roomUserWithProfile,
                                messages: messages,
                                unReadCount: unReadCount,
                                lastMessage: lastMessage,
                                isReported: reportedRoomIds.contains(room.id)
                            ), unReadCount, subscription)
                        }
                    }
                    
                    var newRoomsCount = 0
                    for try await (room, _, subscription) in group {
                        guard let room = room else { continue }
                        self.chatRooms[room.chatRoom.id] = room
                        self.chatRoomSubscriptions[room.chatRoom.id] = subscription
                        newRoomsCount += 1
                    }
                    
                    // Recalculate global unread count
                    self.unreadMessageCount = self.chatRooms.values.map({ $0.unReadCount }).reduce(0, +)
                    
                    if offset == nil {
                        self.currentOffset += newRoomsCount
                    }
                    
                    self.isFetchingChatRooms = true
                }
            }
        } catch let error {
            self.isFetchingChatRooms = true
            if let error = error as? HttpError {
                self.logger.error("❌ Failed to fetch chat rooms: \(error.errorDescription)")
            } else {
                self.logger.error("❌ Failed to fetch chat rooms: \(error.localizedDescription)")
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.isShowAlertFetchingChatRooms.toggle()
            }
        }
    }
    
    @MainActor
    public func makeChatRoom() {
        Task {
            guard let session = await supabase.getSession(),
                  let selectedUser = self.selectedUser,
                  let liker = self.likers.first(where: { $0.user.user.id == selectedUser.user.id }) else { return }
            let chatRoom = ChatRoom(toUserId: selectedUser.user.id,
                                    fromUserId: session.user.id,
                                    createdAt: .now,
                                    recruitmentId: liker.recruitmentId,
                                    talkCount: 8)
            do {
                let response = try await self.http.post(url: .makeChatRoom, content: chatRoom)
                if response.ok {
                    let subscription = try await self.supabase.subscribeChatChannel(roomId: chatRoom.id)
                    self.chatRoomSubscriptions[chatRoom.id] = subscription
                    
                    let recruitments = await self.supabase.selectRecruitment(recruitmentId: chatRoom.recruitmentId)
                    if let recruitment = recruitments?.first, let recruitmentPlaces = recruitment.recruitmentPlaces {
                        let fieldMask = GooglePlaceFieldMask.detailFieldMask.map({ $0.rawValue }).joined(separator: ",")
                        let placeIds = recruitmentPlaces.compactMap({ $0.placeId })
                        let placeDetail = GooglePlacesPlaceDetailBodyParamater(fieldMask: fieldMask, placeIds: placeIds, languageCode: "ja")
                        let placeResponse = try await self.http.post(url: .getPlaceDetails, content: placeDetail)
                        
                        if placeResponse.ok {
                            let places: [GooglePlacesSearchResponsePlace] = try placeResponse.decode()
                            let placesWrapper = places.map({ GooglePlacesSearchPlaceWrapper(place: $0 )})
                            
                            let newChatRoom = ChatRoomWithRecruitment(
                                chatRoom: chatRoom,
                                recruitment: recruitment,
                                places: placesWrapper,
                                roomUser: liker.user,
                                messages: [],
                                unReadCount: 0,
                                lastMessage: "メッセージを送ってみましょう！"
                            )
                            self.selectedChatRoom = newChatRoom
                            self.chatRooms[chatRoom.id] = newChatRoom
                        }
                    }
                    
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.likers.removeAll(where: { $0.user.user.id == selectedUser.user.id })
                    }
                }
            } catch let error {
                if let error = error as? HttpError {
                    self.logger.error("❌ Failed to insert chat room: \(error.errorDescription)")
                }
            }
        }
    }
    
    private func handleInsertAction(_ action: InsertAction) {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .tolerantISO8601
            let message = try action.decodeRecord(as: ChatMessage.self, decoder: decoder)
            Task { @MainActor in
                guard let session = await self.supabase.getSession() else { return }

                // Ignore messages sent by self (already appended locally in sendMessage)
                guard message.fromUserId != session.user.id else { return }

                let roomId = message.roomId

                // Append to the chat room list
                if self.chatRooms[roomId] != nil {
                    // Avoid duplicate if already present
                    guard !self.chatRooms[roomId]!.messages.contains(where: { $0.id == message.id }) else { return }
                    self.chatRooms[roomId]?.messages.append(message)

                    if message.contextType == MessageContentType.image.rawValue {
                        self.chatRooms[roomId]?.lastMessage = "画像が送信されました。"
                    } else {
                        self.chatRooms[roomId]?.lastMessage = message.context
                    }
                }

                // If the user is currently viewing this room, append to selectedChatRoom
                if self.selectedChatRoom?.chatRoom.id == roomId {
                    guard !self.selectedChatRoom!.messages.contains(where: { $0.id == message.id }) else { return }
                    self.selectedChatRoom?.messages.append(message)
                } else {
                    // User is not viewing this room — increment unread count
                    self.chatRooms[roomId]?.unReadCount += 1
                    self.unreadMessageCount += 1
                }
            }
        } catch {
            logger.error("❌ Failed to decode inserted message: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    public func removeChatRoom(roomId: UUID) {
        self.chatRooms.removeValue(forKey: roomId)
    }
    
    @MainActor
    public func syncReadStatus() {
        let unreadIds = self.likers.filter { $0.isRead }.map { $0.id }
        guard !unreadIds.isEmpty else { return }
        
        Task {
            do {
                try await self.supabase.updateLikePairsReadStatus(ids: unreadIds)
            } catch let error {
                self.logger.error("❌ Failed to update read status: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    public func refreshChatRooms() {
        Task {
            self.currentOffset = 0
            await self.fetchChatRooms(offset: 0, limit: 20)
        }
    }
    
    @MainActor
    public func refreshLikers() {
        Task {
            await self.fetchLikers()
        }
    }

    @MainActor
    public func setSelectedChatRoom(withUserId userId: UUID) {
        if let room = self.chatRooms.values.first(where: { $0.roomUser.user.id == userId }) {
            self.selectedChatRoom = room
        }
    }
    
    @MainActor
    public func checkEnableTalk() async {
        do {
            self.isIdentityVerified = try await self.supabase.checkIsIdentityVerified()
            self.isSubscribed = try await self.supabase.checkSubscribed()
            
            if let user = try? await self.supabase.fetchUser() {
                self.isWoman = (user.sex == "woman" || user.sex == "女性")
            }
            
            if isWoman {
                self.isEnableTalk = self.isIdentityVerified
            } else {
                self.isEnableTalk = self.isIdentityVerified && self.isSubscribed
            }
        } catch let error {
            self.logger.error("❌ Failed to check enable to talk: \(error.localizedDescription)")
        }
    }
}
