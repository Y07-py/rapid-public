//
//  RecruitmentViewModel.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/26.
//

import Foundation
import SwiftUI
import CoreLocation
import Combine

public class RecruitmentViewModel: ObservableObject {
    @Published var recruitments: [RecruitmentWithUserProfile] = []
    @Published var selectedRecruitment: RecruitmentWithUserProfile? = nil
    @Published var nearestTransports: [GooglePlacesTransport] = []
    @Published var isLoadingNearestTransports: Bool = false
    @Published var isLoadingDetail: Bool = false
    
    @Published var ageRange: FetchRecruitmentRequestParamaterWithAgeRange? = nil
    @Published var residenceRadius: Double? = nil
    @Published var locationKeyword: String? = nil
    @Published var sortLogin: Bool = false
    @Published var isLoading: Bool = false
    @Published var recruitmentsOffset: Int = 0
    @Published var isFetchingRecruitments: Bool = false
    @Published var isMatched: Bool = false
    
    private let http: HttpClient = {
        let client = HttpClient(auth: HttpSupabaseAuthenticator(), retryPolicy: .exponentialBackoff(3, 4.5))
        return client
    }()
    private let logger = Logger.shared
    private let supabase = SupabaseManager.shared
    private let coreData = CoreDataStack.shared
    private let recruitmentsLimit: Int = 10
    
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
    }
    
    @MainActor
    private func startNetworkInitialization() async {
        self.recruitments = await self.fetchRecruitments(offset: 0)
        self.initRecruitmentFilter()
        self.isDataLoaded = true
    }
}

extension RecruitmentViewModel {
    @MainActor
    private func initRecruitmentFilter() {
        guard let filter = self.coreData.fetchRecruitmentFilter() else { return }
        self.ageRange = filter.ageRange
        self.residenceRadius = filter.residenceRadius
        self.locationKeyword = filter.locationKeyword
        self.sortLogin = filter.sortLogin
    }
    
    @MainActor
    private func fetchRecruitments(offset: Int, limit: Int = 10, filter: FetchRecruitmentRequestParamaterWithFilter? = nil) async -> [RecruitmentWithUserProfile] {
        self.isLoading = true
        defer { self.isLoading = false }
        do {
            guard let session = await self.supabase.getSession() else { return [] }
            let reqParam = FetchRecruitmentRequestParamater(
                userId: session.user.id,
                offset: offset,
                limit: limit,
                filterParamater: filter
            )
            let resp = try await http.post(url: .fetchRecruitment, content: reqParam)
            let recruitmentObjects: [RecruitmentWithLike]? = try resp.decode(dateDecodingStrategy: .tolerantISO8601)
            
            if let recruitmentObjects = recruitmentObjects {
                return try await self.processRecruitmentObjects(recruitmentObjects)
            }
        } catch let error {
            logger.error("❌ Failed to fetch recruitments: \(error.localizedDescription)")
        }
        
        return []
    }
    
    @MainActor
    public func updateRecruitmentsOffset() {
        Task {
            // Guard double loading.
            guard !self.isFetchingRecruitments else { return }
            self.isFetchingRecruitments = true
            
            let filter = self.buildFilter()
            let nextOffset = self.recruitmentsOffset + self.recruitmentsLimit

            let newRecruitments = await self.fetchRecruitments(offset: nextOffset, filter: filter)
            
            if !newRecruitments.isEmpty {
                self.recruitments.append(contentsOf: newRecruitments)
                self.recruitmentsOffset = nextOffset
            }
            
            self.isFetchingRecruitments = false
        }
    }
    
    @MainActor
    private func buildFilter() -> FetchRecruitmentRequestParamaterWithFilter {
        return FetchRecruitmentRequestParamaterWithFilter(
            ageRange: self.ageRange,
            residenceRadius: self.residenceRadius,
            locationKeyword: self.locationKeyword,
            sortLogin: self.sortLogin
        )
    }
    
    @MainActor
    private func processRecruitmentObjects(_ objects: [RecruitmentWithLike]) async throws -> [RecruitmentWithUserProfile] {
        return try await withThrowingTaskGroup(of: RecruitmentWithUserProfile.self) { [weak self] group in
            guard let self = self else { return [] }
            var results: [RecruitmentWithUserProfile] = []
            
            for recruitment in objects {
                group.addTask {
                    let userId = recruitment.recruitmentWithRelations.userId!
                    let userWithProfile = try await self.supabase.fetchUserWithProfile(userId: userId)
                    let placeIds = recruitment.recruitmentWithRelations.recruitmentPlaces?.compactMap({ $0.placeId })
                    let places = try await self.fetchPlaceDetail(placeIds: placeIds ?? [], isDetail: false)
                    let placesWrapper = places.map({ GooglePlacesSearchPlaceWrapper(place: $0 ) })
                    
                    return .init(profile: userWithProfile, places: placesWrapper, recruitment: recruitment)
                }
            }
            
            for try await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    private func fetchPlaceDetail(placeIds: [String], isDetail: Bool) async throws -> [GooglePlacesSearchResponsePlace] {
        // fetch place detail via google plcaes api.
        let fieldMask = (isDetail ? GooglePlaceFieldMask.detailFieldMask : GooglePlaceFieldMask.defaultFieldMask)
            .map({ $0.rawValue }).joined(separator: ",")
        let param = GooglePlacesPlaceDetailBodyParamater(fieldMask: fieldMask, placeIds: placeIds, languageCode: "ja")
        
        let resp = try await http.post(url: .getPlaceDetails, content: param)
        let placeDetails: [GooglePlacesSearchResponsePlace] = try resp.decode()
        
        return placeDetails
    }
    
    @MainActor
    public func fetchFullRecruitmentDetail(recruitmentId: UUID) async {
        guard let idx = self.recruitments.firstIndex(where: { $0.id == recruitmentId }) else { return }
        
        self.isLoadingDetail = true
        defer { self.isLoadingDetail = false }
        
        do {
            let recruitment = self.recruitments[idx]
            let placeIds = recruitment.recruitment.recruitmentWithRelations.recruitmentPlaces?.compactMap({ $0.placeId }) ?? []
            
            if placeIds.isEmpty { return }
            
            let fullPlaces = try await self.fetchPlaceDetail(placeIds: placeIds, isDetail: true)
            let fullPlacesWrapper = fullPlaces.map({ GooglePlacesSearchPlaceWrapper(place: $0) })
            
            // Update the recruitment object with full field data
            self.recruitments[idx].places = fullPlacesWrapper
            
            // If this is the currently selected recruitment, update it too
            if self.selectedRecruitment?.id == recruitmentId {
                self.selectedRecruitment?.places = fullPlacesWrapper
            }
        } catch let error {
            logger.error("❌ Failed to fetch full recruitment detail: \(error.localizedDescription)")
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
    
    @MainActor
    public func sendLike() {
        Task {
            guard let recruitment = self.selectedRecruitment,
                  let session = await supabase.getSession() else { return }
            
            // Check if the other user already liked the current user (Matching)
            let existingLike = try? await supabase.checkExistLikePair(
                fromUserId: recruitment.recruitment.recruitmentWithRelations.userId!,
                toUserId: session.user.id
            )
            
            if existingLike != nil {
                self.isMatched = true
                logger.info("🎉 Perfect Match detected!")
                let userId = recruitment.recruitment.recruitmentWithRelations.userId?.uuidString.lowercased() ?? ""
                NotificationCenter.default.post(name: .matchingNotification, object: nil, userInfo: ["user_id": userId])
            }
            
            let likePair = LikePair(
                fromUserId: session.user.id,
                toUserId: recruitment.recruitment.recruitmentWithRelations.userId!,
                likedAt: .now,
                matched: self.isMatched,
                isRead: false,
                recruitmentId: recruitment.recruitment.recruitmentWithRelations.id,
                grade: "default"
            )
            
            do {
                let response = try await http.post(
                    url: .sendLike,
                    content: likePair,
                    dateEncodingStrategy: .tolerantISO8601
                )
                if response.ok {
                    logger.info("✅ Successfully to like recruitment.")
                    if let idx = self.recruitments.firstIndex(where: { $0.id == recruitment.id }) {
                        let like = LikeRecruitment(
                            id: .init(),
                            userId: likePair.fromUserId,
                            recruitmentId: likePair.recruitmentId,
                            likedAt: likePair.likedAt,
                            grade: "default"
                        )
                        self.recruitments[idx].recruitment.like = like
                        self.selectedRecruitment?.recruitment.like = like
                    }
                }
            } catch let error {
                if let error = error as? HttpError {
                    logger.error("❌ Failed to like recruitment. \(error.errorDescription)")
                }
            }
        }
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
    
    @MainActor
    public func fetchRecruitmentWithFilter() {
        Task {
            let filter = FetchRecruitmentRequestParamaterWithFilter(
                ageRange: self.ageRange,
                residenceRadius: self.residenceRadius,
                locationKeyword: self.locationKeyword,
                sortLogin: self.sortLogin
            )
            // Fetch recruitment result
            let results = await self.fetchRecruitments(offset: 0, filter: filter)
            self.recruitments = results
            // Save recruitment filter in CoreData
            self.coreData.saveRecruitmentFilter(filter: filter)
        }
    }
}
