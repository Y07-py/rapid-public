//
//  VoiceChatViewModel.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/18.
//

import Foundation
import SwiftUI
import CoreLocation
import Combine
import WebRTC
import AVFoundation

public class VoiceChatViewModel: ObservableObject {
    private let logger = Logger.shared
    private let supabase = SupabaseManager.shared
    private let http: HttpClient = {
        let client = HttpClient(auth: HttpSupabaseAuthenticator(), retryPolicy: .exponentialBackoff(3, 4.5))
        return client
    }()
    
    @Published var voiceChatRooms: [VoiceChatRoomWithUserProfile] = []
    @Published var selectedVoiceChatRoom: VoiceChatRoomWithUserProfile? = nil
    @Published var nearestTransports: [GooglePlacesTransport] = []
    @Published var isLoadingNearestTransports: Bool = false
    @Published var cityCoordinates: [CityCoordinate] = []
    @Published var voiceChatFilter: FetchVoiceChatRoomFilter? = nil
    @Published var votingEvent: VoiceChatEvent? = nil
    @Published var votingPlaces: [GooglePlacesSearchPlaceWrapper] = []
    @Published var selectedVotingPlace: GooglePlacesSearchPlaceWrapper? = nil
    @Published var detailViewingPlace: GooglePlacesSearchPlaceWrapper? = nil
    @Published var joinedEventUser: VoiceChatEventJoinedUser? = nil
    @Published var matchedPairs: [VoiceChatEventPair] = []
    @Published var partnerProfiles: [RapidUserWithProfile] = []
    @Published var matchedPlace: GooglePlacesSearchPlaceWrapper? = nil
    
    @Published var likedVoiceChatRoomUsers: [RapidUserWithProfile] = []
    @Published var matchedVoiceChatUsers: [RapidUserWithProfile] = []
    @Published var isFetchingLikedUsers: Bool = false
    @Published var isFetchingMatchedUsers: Bool = false
    
    @Published var isShowLikeAnimation: Bool = false
    
    @Published var isIdentityVerified: Bool = false
    @Published var isSubscribed: Bool = false
    @Published var isWoman: Bool = false
    @Published var isEnableTalk: Bool = false
    @Published var isShowPermissionFlow: Bool = false
    
    // WebRTC
    @Published var webRTCClient: WebRTCClient?
    @Published var signalingClient: SignalingClient?
    @Published var isVoiceChatConnected: Bool = false
    @Published var isWaitingForVoiceChat: Bool = false
    @Published var webRTCConnectionState: RTCIceConnectionState = .new
    @Published var waitingUser: WaitingUser? = nil
    @Published var isJoinLeaveLoading: Bool = false
    @Published var isShowCallView: Bool = false
    @Published var currentCallId: String = ""
    @Published var currentCallRole: CallingRole = .caller
    @Published var callOpponentName: String? = nil
    @Published var callOpponentImageURL: URL? = nil
    @Published var isShowMicrophoneAlert: Bool = false
    
    private var voiceChatRole: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var isDataLoaded = false
    private var targetSex: String = "woman" // Default, will be updated from profile
    
    public var uniquePrefectures: [String] {
        let prefs = Array(Set(cityCoordinates.map { $0.prefecture })).sorted()
        return ["未設定"] + prefs
    }

    
    init() {
        self.loadCityCoordinates()
        
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
        
        NotificationCenter.default.addObserver(forName: .matchingNotification, object: nil, queue: .main) { notification in
            if let userId = notification.userInfo?["user_id"] as? String {
                Task { @MainActor in
                    self.removeMatchedVoiceChatRoom(userId: userId)
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: .receiveVoiceChatStartedNotification, object: nil, queue: .main) { notification in
            
        }
        
        NotificationCenter.default.addObserver(forName: .receiveVoiceChatMatchedNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let callId = notification.userInfo?["call_id"] as? String,
                  let role = notification.userInfo?["role"] as? String,
                  let opponentUserId = notification.userInfo?["opponent_user_id"] as? String else { return }
            
            Task { @MainActor in
                await self.startVoiceChatSignaling(callId: callId, role: role, opponentUserId: opponentUserId)
            }
        }
        
        Task { @MainActor in
            await self.checkEnableTalk()
        }
    }
    
    @MainActor
    private func startNetworkInitialization() async {
        // Determine target sex first
        if let session = await self.supabase.getSession() {
            do {
                let userWithProfile = try await self.supabase.fetchUserWithProfile(userId: session.user.id)
                let userSex = userWithProfile.user.sex ?? "man"
                // The DB uses "man" and "woman" for filtering
                if userSex == "woman" || userSex == "女性" {
                    self.targetSex = "man"
                } else {
                    self.targetSex = "woman"
                }
                
                // Initialize default filter with target sex
                if self.voiceChatFilter == nil {
                    self.voiceChatFilter = FetchVoiceChatRoomFilter(
                        fromAge: 18,
                        toAge: 80,
                        sex: self.targetSex,
                        residence: nil,
                        radius: nil
                    )
                } else {
                    self.voiceChatFilter?.sex = self.targetSex
                }
            } catch {
                self.logger.error("❌ Failed to fetch user profile for gender filtering: \(error.localizedDescription)")
            }
        }

        let rooms = await self.fetchVoiceChatRoom(offset: 0)
        do {
            let matchedUserIds = try await self.supabase.fetchMatchedUserIds()
            self.voiceChatRooms = rooms.filter { !matchedUserIds.contains($0.profile.user.id) }
        } catch {
            self.logger.error("❌ Failed to fetch matched user ids: \(error.localizedDescription)")
            self.voiceChatRooms = rooms
        }
        
        await self.fetchVoiceChatEvents()
        self.isDataLoaded = true
    }
}

extension VoiceChatViewModel {
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
    
    @MainActor
    public func checkSubscribed() async -> Bool {
        do {
            return try await self.supabase.checkSubscribed()
        } catch let error {
            self.logger.error("❌ Failed to check whether subscriebed: \(error.localizedDescription)")
            return false
        }
    }
    
    @MainActor
    public func fetchVoiceChatRoom(offset: Int) async -> [VoiceChatRoomWithUserProfile] {
        guard let session = await self.supabase.getSession() else { return [] }
        // Ensure filter is present
        let filter = self.voiceChatFilter ?? FetchVoiceChatRoomFilter(
            fromAge: 18,
            toAge: 80,
            sex: self.targetSex,
            residence: nil,
            radius: nil
        )
        
        let param = FetchVoiceChatRoomParamater(
            userId: session.user.id,
            pageOffset: offset,
            pageLimit: 10,
            filter: filter
        )
        
        do {
            let response = try await self.http.post(url: .fetchVoiceChatRoom, content: param)
            if response.ok {
                let voiceChatRooms: [VoiceChatRoomWithRecruitment]? = try response.decode(dateDecodingStrategy: .tolerantISO8601)
                if let voiceChatRooms = voiceChatRooms {
                    return try await withThrowingTaskGroup(of: (VoiceChatRoomWithUserProfile?).self) { group in
                        var voiceChatRoomWithProfiles: [VoiceChatRoomWithUserProfile] = []
                        for room in voiceChatRooms {
                            group.addTask {
                                let userId = room.voiceChatRoom.userAId
                                let userWithProfile = try await self.supabase.fetchUserWithProfile(userId: userId)
                                let placeIds: [String] = [] // Recruitment relation is removed, place handling depends on voting event
                                let places = await self.fetchPlaceDetail(placeIds: placeIds)
                                
                                let liked = try await self.supabase.checkLikedVoiceChatRoom(roomId: room.voiceChatRoom.id)
                                
                                return VoiceChatRoomWithUserProfile(
                                    profile: userWithProfile,
                                    voiceChatRoomWithRecruitment: room,
                                    places: places,
                                    checked: liked
                                )
                            }
                        }
                        
                        for try await roomWithProfile in group {
                            if let roomWithProfile = roomWithProfile {
                                voiceChatRoomWithProfiles.append(roomWithProfile)
                            }
                        }
                        
                        return voiceChatRoomWithProfiles
                    }
                } else {
                    self.logger.warning("⚠️ return object is nil.")
                }
            }
        } catch let error {
            if let error = error as? HttpError {
                self.logger.error("❌ Failed to fetch voice chat room. \(error.errorDescription)")
            } else {
                self.logger.error("❌ Failed to decode voice chat room: \(error.localizedDescription)")
            }
        }
        
        return []
    }
    
    // MARK: - Place detail
    private func fetchPlaceDetail(
        _ wrapper: GooglePlacesSearchPlaceWrapper,
        fieldMask: [GooglePlaceFieldMask] = GooglePlaceFieldMask.detailFieldMask
    ) async -> GooglePlacesSearchPlaceWrapper? {
        guard let placeId = wrapper.place?.id else { return nil }
        let fieldMaskJoined = fieldMask.map({ $0.rawValue }).joined(separator: ",")
        let param = GooglePlacesPlaceDetailBodyParamater(fieldMask: fieldMaskJoined, placeIds: [placeId], languageCode: "ja")
        
        do {
            let resp = try await http.post(url: .getPlaceDetails, content: param)
            if resp.ok {
                let places: [GooglePlacesSearchResponsePlace] = try resp.decode()
                if let first = places.first {
                    return GooglePlacesSearchPlaceWrapper(place: first)
                }
            }
        } catch let error {
            logger.error("❌ Failed to fetch place detail: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchPlaceDetail(placeIds: [String]?) async -> [GooglePlacesSearchPlaceWrapper] {
        guard let placeIds = placeIds, !placeIds.isEmpty else { return [] }
        let fieldMask = GooglePlaceFieldMask.detailFieldMask.map({ $0.rawValue }).joined(separator: ",")
        let param = GooglePlacesPlaceDetailBodyParamater(fieldMask: fieldMask, placeIds: placeIds, languageCode: "ja")
        
        do {
            let response = try await self.http.post(url: .getPlaceDetails, content: param)
            if response.ok {
                let places: [GooglePlacesSearchResponsePlace] = try response.decode()
                return places.map({ GooglePlacesSearchPlaceWrapper(place: $0) })
            }
        } catch let error {
            if let error = error as? HttpError {
                self.logger.error("❌ Failed to fetch places details: \(error.errorDescription)")
            } else {
                self.logger.error("❌ Failed to decode place details: \(error.localizedDescription)")
            }
        }
        
        return []
    }
    
    @MainActor
    public func updatePlaceDetail() async {
        guard let wrapper = self.detailViewingPlace else { return }
        if let place = await self.fetchPlaceDetail(wrapper)?.place {
            if self.detailViewingPlace?.place?.reviews == nil {
                self.detailViewingPlace?.place?.reviews = place.reviews
            }
            
            if self.detailViewingPlace?.place?.currentOpeningHours == nil {
                self.detailViewingPlace?.place?.currentOpeningHours = place.currentOpeningHours
            }
            
            if self.detailViewingPlace?.place?.websiteUri == nil {
                self.detailViewingPlace?.place?.websiteUri = place.websiteUri
            }
            
            if self.detailViewingPlace?.place?.priceLevel == nil {
                self.detailViewingPlace?.place?.priceLevel = place.priceLevel
            }
            
            if self.detailViewingPlace?.place?.priceRange == nil {
                self.detailViewingPlace?.place?.priceRange = place.priceRange
            }
            
            await self.updateNearestTransport(wrapper: self.detailViewingPlace!)
        }
    }
    
    @MainActor
    public func submitVoiceChatVote(user: RapidUserWithProfile) async {
        guard let session = await self.supabase.getSession() else { return }
        guard let event = self.votingEvent else { return }
        guard let selectedPlace = self.selectedVotingPlace?.place?.id else { return }
        
        let body = VoiceChatEventJoinedUser(
            userId: session.user.id,
            eventId: event.eventId,
            participatedAt: .now,
            selectedPlaceId: selectedPlace,
            sex: user.user.sex
        )
        
        do {
            try await self.supabase.upsertVoiceChatEventJoinedUser(body: body)
            self.joinedEventUser = body
            self.logger.info("✅ Successfully submitted voice chat vote for place: \(selectedPlace)")
        } catch {
            self.logger.error("❌ Failed to submit voice chat vote: \(error.localizedDescription)")
        }
    }
    
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
    
    
    // MARK: - Send like to voice chat room
    @MainActor
    public func sendLikeToVoiceChatRoom(room: VoiceChatRoomWithUserProfile) {
        Task {
            guard let session = await self.supabase.getSession() else { return }
            let payload = LikeVoiceChatRoom(
                userId: session.user.id,
                roomId: room.voiceChatRoomWithRecruitment.voiceChatRoom.id,
                likedAt: .now
            )
            
            do {
                let response = try await self.http.post(url: .sendLikeToVoiceChatRoom, content: payload)
                if response.ok {
                    guard let idx = self.voiceChatRooms.firstIndex(where: { $0.id == room.id }) else { return }
                    
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.voiceChatRooms[idx].checked = true
                    }
                }
            } catch let error {
                if let error = error as? HttpError {
                    self.logger.error("❌ Failed to send like voice chat room. \(error.errorDescription)")
                } else {
                    self.logger.error("❌ Failed to send like voice chat room: \(error.localizedDescription)")
                }
            }
        }
    }
    
    
    @MainActor
    private func removeMatchedVoiceChatRoom(userId: String) {
        guard let uuid = UUID(uuidString: userId) else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            self.voiceChatRooms.removeAll { $0.profile.user.id == uuid }
        }
    }
    
    @MainActor
    public func sendCallMessage(
        profile: RapidUserWithProfile,
        completion: @escaping (_ client: SignalingClient?, _ callId: String, _ clientId: String) -> Void
    ) {
        Task {
            guard let session = await self.supabase.getSession() else { return }
            let callId = UUID().uuidString.lowercased()
            let callPayload = CallPayload(
                aps: .init(contentAvailable: 1),
                callId: callId,
                callerName: profile.user.userName ?? "No Name",
                handle: profile.user.id.uuidString.lowercased()
            )
            let callObject = CallObject(userId: session.user.id, payload: callPayload)
            
            do {
                let response = try await self.http.post(url: .sendCallMessage, content: callObject)
                if response.ok {
                    let client = self.makeSignalingClient(callId: callId, clientId: session.user.id.uuidString.lowercased())
                    completion(client, callId, session.user.id.uuidString.lowercased())
                }
            } catch let error {
                if let error = error as? HttpError {
                    self.logger.error("❌ Failed to send call message: \(error.errorDescription)")
                }
            }
        }
    }
    
    @MainActor
    private func startVoiceChatSignaling(callId: String, role: String, opponentUserId: String) async {
        guard let session = await self.supabase.getSession() else { return }
        let clientId = session.user.id.uuidString.lowercased()
        
        // Removed: self.isWaitingForVoiceChat = false (Handled in CallView onAppear)
        
        // Initialize WebRTC and Signaling
        let webRTCClient = WebRTCClient(iceServers: Config.default.webRTCIceServers)
        let provider = SupabaseRealtimeProvider(callId: callId)
        let signalingClient = SignalingClient(clientId: clientId, webSocket: provider)
        
        webRTCClient.delegate = self
        signalingClient.delegate = self
        
        self.webRTCClient = webRTCClient
        self.signalingClient = signalingClient
        self.voiceChatRole = role // Set the role here
        
        self.currentCallId = callId
        self.currentCallRole = role == "caller" ? .caller : .callee
        
        // Fetch opponent's profile
        if let uuid = UUID(uuidString: opponentUserId) {
            do {
                let opponentProfile = try await self.supabase.fetchUserWithProfile(userId: uuid)
                self.callOpponentName = opponentProfile.user.userName
                self.callOpponentImageURL = opponentProfile.profileImages.first?.imageURL
            } catch {
                self.logger.error("❌ Failed to fetch opponent profile: \(error.localizedDescription)")
            }
        }
        
        signalingClient.connect()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            self.isShowCallView = true
        }
        
        if role == "caller" {
            self.logger.info("ℹ️ Starting WebRTC Signaling as Caller (Waiting for connection to send Offer)")
        } else {
            self.logger.info("ℹ️ Starting WebRTC Signaling as Callee (Waiting for Offer)")
        }
    }
    
    public func endVoiceChat() {
        self.signalingClient?.close()
        self.webRTCClient?.close()
        self.signalingClient = nil
        self.webRTCClient = nil
        self.isVoiceChatConnected = false
    }
    
    private func makeSignalingClient(callId: String, clientId: String) -> SignalingClient? {
        let provider = SupabaseRealtimeProvider(callId: callId)
        let client = SignalingClient(
            clientId: clientId,
            webSocket: provider
        )
        
        return client
    }
    
    @MainActor
    public func updateNearestTransport(wrapper: GooglePlacesSearchPlaceWrapper) async {
        self.isLoadingNearestTransports = true
        defer { self.isLoadingNearestTransports = false }
        
        self.nearestTransports.removeAll()
        guard let place = wrapper.place,

              let latitude = place.location?.latitude,
              let longitude = place.location?.longitude else { return }
        
        let placeTypes: [GooglePlaceType] = [.trainStation, .subwayStation, .busStation, .airport, .ferryTerminal]
        let fieldMask: [GooglePlaceFieldMask] = [.id, .displayName, .location, .types]
        
        let body = GooglePlacesNearbySearchBodyParamater(
            includedTypes: placeTypes,
            maxResultCount: 10,
            languageCode: "ja",
            rankPreference: "DISTANCE",
            locationRestriction: .init(circle: .init(latitude: latitude, longitude: longitude, radius: 1000))
        )
        
        let fieldMaskString = fieldMask.map({ "places.\($0.rawValue)" }).joined(separator: ",")
        
        // Use a dummy window size for client paramater
        let clientParam = PlaceSearchClientParamater(
            latitude: latitude,
            longitude: longitude,
            zoom: 13,
            windowSize: CGSize(width: 375, height: 812), // iPhone 13 dummy size
            scale: 3.0
        )
        
        let param = GooglePlacesNearbySearchParamater(requestParamater: body, fieldMask: fieldMaskString, clientParamater: clientParam)
        
        do {
            let response = try await http.post(url: .searchNearbyTransports, content: param)
            if response.ok {
                let places: [GooglePlacesSearchResponsePlace] = try response.decode()
                let transports = places.compactMap({ place in
                    if let lat = place.location?.latitude,
                       let lon = place.location?.longitude {
                        let d = self.computeDistance(lat1: latitude, lon1: longitude, lat2: lat, lon2: lon)
                        return GooglePlacesTransport(l2Distance: d, place: place)
                    }
                    return nil
                })
                self.nearestTransports = transports
            }
        } catch let error {
            self.logger.error("❌ Failed to fetch nearest transports: \(error.localizedDescription)")
        }
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
    
    private func loadCityCoordinates() {
        guard let url = Bundle.main.url(forResource: "prefecture_cities_coordinates", withExtension: "csv") else {
            self.logger.error("❌ Failed to find csv file.")
            return
        }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            var coordinates: [CityCoordinate] = []
            for (index, line) in lines.enumerated() {
                if index == 0 || line.isEmpty { continue }
                
                let columns = line.components(separatedBy: ",")
                if columns.count >= 4 {
                    let pref = columns[0]
                    let city = columns[1]
                    if let lon = Double(columns[2]), let lat = Double(columns[3]) {
                        coordinates.append(CityCoordinate(prefecture: pref, city: city, longitude: lon, latitude: lat))
                    }
                }
            }
            self.cityCoordinates = coordinates
            self.logger.info("✅ Successfully loaded \(coordinates.count) city coordinates.")
        } catch let error {
            self.logger.error("❌ Failed to load csv file: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    public func applyFilter(fromAge: Int, toAge: Int, prefecture: String, radius: Int?, useDistance: Bool) {
        var residenceModel: FetchVoiceChatRoomResidence? = nil
        
        if prefecture != "未設定" {
            if let cityCoord = cityCoordinates.first(where: { $0.prefecture == prefecture }) {
                residenceModel = FetchVoiceChatRoomResidence(
                    name: prefecture,
                    latitude: cityCoord.latitude,
                    longitude: cityCoord.longitude
                )
            }
        }
        
        let filter = FetchVoiceChatRoomFilter(
            fromAge: fromAge,
            toAge: toAge,
            sex: self.targetSex,
            residence: residenceModel,
            radius: useDistance ? radius : nil
        )
        
        self.voiceChatFilter = filter
        
        Task {
            self.voiceChatRooms = await self.fetchVoiceChatRoom(offset: 0)
        }
    }
    
    @MainActor
    private func fetchVoiceChatEvents() async {
        do {
            guard let event = try await self.supabase.selectLatestVoiceChatEvent() else {
                self.votingEvent = nil
                self.votingPlaces = []
                self.joinedEventUser = nil
                self.matchedPairs = []
                self.partnerProfiles = []
                self.matchedPlace = nil
                self.logger.info("ℹ️ No voice chat event found.")
                return
            }
            
            self.votingEvent = event
            self.logger.info("✅ Latest event found: \(event.eventId), status: \(event.status)")
            
            if event.status == "voting" {
                self.votingPlaces = await self.fetchPlaceDetail(placeIds: event.placeIds)
                self.logger.info("✅ Fetched \(self.votingPlaces.count) voting places")
                self.selectedVotingPlace = nil
                
                // Check if user already joined this event
                self.joinedEventUser = try? await self.supabase.fetchVoiceChatEventJoinedUser(eventId: event.eventId)
                if let joined = self.joinedEventUser {
                    self.logger.info("ℹ️ User already joined this event. Selected place: \(joined.selectedPlaceId ?? "unknown")")
                    // Pre-select the place the user voted for
                    if let placeId = joined.selectedPlaceId {
                        self.selectedVotingPlace = self.votingPlaces.first(where: { $0.place?.id == placeId })
                    }
                }
            } else if event.status == "starting" {
                self.logger.info("ℹ️ Event status is starting. Fetching matched spot from user's vote.")
                self.joinedEventUser = try? await self.supabase.fetchVoiceChatEventJoinedUser(eventId: event.eventId)
                
                if let joined = self.joinedEventUser, let placeId = joined.selectedPlaceId {
                    await self.fetchMatchedPlace(placeId: placeId)
                    self.logger.info("✅ Matched spot fetched: \(placeId)")
                } else {
                    self.logger.warning("⚠️ User didn't participate in voting, or place info is missing.")
                }
            }
        } catch {
            self.logger.error("❌ Failed to fetch voice chat events: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func fetchMatchedPartnerProfiles(userIds: [UUID]) async {
        do {
            var fetchedProfiles: [RapidUserWithProfile] = []
            for userId in userIds {
                let profile = try await self.supabase.fetchUserWithProfile(userId: userId)
                fetchedProfiles.append(profile)
            }
            self.partnerProfiles = fetchedProfiles
        } catch {
            self.logger.error("❌ Failed to fetch partner profiles: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func fetchMatchedPlace(placeId: String) async {
        let places = await self.fetchPlaceDetail(placeIds: [placeId])
        self.matchedPlace = places.first
    }
    
    @MainActor
    public func joinVoiceChat() {
        Task {
            // Check identity verification and subscription if needed
            await self.checkEnableTalk()
            if !self.isEnableTalk {
                self.isShowPermissionFlow = true
                return
            }

            // Check microphone permission before joining
            let isGranted = await self.checkMicrophonePermission()
            if !isGranted {
                self.isShowMicrophoneAlert = true
                return
            }

            guard let eventUser = self.joinedEventUser else { return }
            let body = WaitingUser(userId: eventUser.userId, enteredAt: .now, sex: eventUser.sex!, placeId: eventUser.selectedPlaceId!)
            
            self.isJoinLeaveLoading = true
            defer { self.isJoinLeaveLoading = false }
            
            do {
                let respnose = try await self.http.post(url: .joinVoiceChat, content: body)
                if respnose.ok {
                    self.waitingUser = body
                    // If a match was found and signaling has already started via FCM, 
                    // don't reset to waiting state.
                    if self.signalingClient == nil {
                        withAnimation(.spring()) {
                            self.isWaitingForVoiceChat = true
                        }
                    } else {
                        self.logger.info("ℹ️ Match found during join process, skipping waiting animation.")
                    }
                    self.isJoinLeaveLoading = false
                }
            } catch let error {
                if let error = error as? HttpError {
                    self.logger.error("❌ Failed to join voice chat: \(error.errorDescription)")
                } else {
                    self.logger.error("❌ Failed to join voice chat: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @MainActor
    private func checkMicrophonePermission() async -> Bool {
        let status = AVAudioApplication.shared.recordPermission
        
        switch status {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            // Request permission
            return await AVAudioApplication.requestRecordPermission()
        @unknown default:
            return false
        }
    }
    
    @MainActor
    public func leaveVoiceChat() {
        Task {
            guard let waitingUser = self.waitingUser else { return }
            
            self.isJoinLeaveLoading = true
            defer { self.isJoinLeaveLoading = false }
            
            do {
                let response = try await self.http.post(url: .leaveVoiceChat, content: waitingUser)
                if response.ok {
                    self.isJoinLeaveLoading = false
                    withAnimation(.spring()) {
                        self.isWaitingForVoiceChat = false
                    }
                    self.waitingUser = nil
                }
            } catch let error {
                if let error = error as? HttpError {
                    self.logger.error("❌ Failed leave voice chat: \(error.errorDescription)")
                } else {
                    self.logger.error("❌ Failed leave voice chat: \(error.localizedDescription)")
                }
            }
        }
    }
}

extension VoiceChatViewModel: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        self.signalingClient?.send(candidate: candidate)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        Task { @MainActor in
            self.webRTCConnectionState = state
            switch state {
            case .connected, .completed:
                self.isVoiceChatConnected = true
                self.logger.info("✅ WebRTC Connected")
            case .disconnected, .failed, .closed:
                self.isVoiceChatConnected = false
                self.logger.info("ℹ️ WebRTC Disconnected")
            default:
                break
            }
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        // Handle data channel messages if needed
    }
}

extension VoiceChatViewModel: SignalingClientDelegate {
    func signalClientDidConnect(_ signalClient: SignalingClient) {
        self.logger.info("✅ Signaling Client Connected")
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        self.logger.info("ℹ️ Signaling Client Disconnected")
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        self.logger.info("ℹ️ Received Remote SDP: \(sdp.type.rawValue)")
        self.webRTCClient?.set(remoteSdp: sdp) { [weak self] error in
            if let error = error {
                self?.logger.error("❌ Failed to set remote SDP: \(error.localizedDescription)")
                return
            }
            
            if sdp.type == .offer {
                self?.webRTCClient?.answer { answerSdp in
                    self?.signalingClient?.send(sdp: answerSdp)
                }
            }
        }
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate) {
        self.logger.info("ℹ️ Received Remote ICE Candidate")
        self.webRTCClient?.set(remoteCandidate: candidate)
    }
    
    func signalClientDidReceiveBye(_ signalClient: SignalingClient) {
        self.logger.info("ℹ️ Received Bye signal from remote")
        Task { @MainActor in
            withAnimation {
                self.isShowCallView = false
                self.webRTCClient?.close()
                self.signalingClient?.close()
                self.webRTCClient = nil
                self.signalingClient = nil
            }
        }
    }
}
