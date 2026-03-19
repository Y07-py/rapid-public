//
//  LocationSelectViewModel.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/12/30.
//

import Foundation
import SwiftUI
import MapKit
import Combine
import CoreLocation

fileprivate enum PlaceCategory: Hashable {
    case famous
    case romantic
    case lively
    case relaxed
}

public class LocationSelectViewModel: ObservableObject {
    @Published var zoom: Float = 13
    @Published var userLocation: UserLocation? = nil
    
    // Famous locations property
    @Published var famousPlaces: [GooglePlacesSearchPlaceWrapper] = []
    @Published var romanticPlaces: [GooglePlacesSearchPlaceWrapper] = []
    @Published var relaxedPlaces: [GooglePlacesSearchPlaceWrapper] = []
    
    @Published var activeRecruitment: Recruitment? = nil
    @Published var activeRecruitmentPlaces: [GooglePlacesSearchPlaceWrapper] = []
    @Published var isLoading: Bool = false
    @Published var livelyPlaces: [GooglePlacesSearchPlaceWrapper] = []
    @Published var naturalPlaces: [GooglePlacesSearchPlaceWrapper] = []
    
    // Selected location
    @Published var selectedPlace: GooglePlacesSearchPlaceWrapper? = nil
    @Published var selectedCandidates: [GooglePlacesSearchPlaceWrapper] = []
    @Published var directRecruitmentPlace: GooglePlacesSearchPlaceWrapper? = nil
    @Published var nearestTransports: [GooglePlacesTransport] = []
    @Published var textSearchResults: [GooglePlacesSearchPlaceWrapper] = []
    @Published var nearestLocations: [GooglePlacesTransport] = []
    @Published var selectedNearestWrapper: GooglePlacesTransport? = nil
    
    // Recruitment edit
    @Published var recruitmentStartDate: Date = .now
    @Published var recruitmentEndDate: Date = .now
    @Published var dateType: RecruitmentDateType = .free
    @Published var messageText: String = ""
    @Published var recruitmentSelectedIds: Set<String> = []
    
    // Search paramater and properties
    @Published var locationCategories: [LocationCategory] = []
    @Published var selectedLocationCategory: [LocationCategory] = []
    @Published var searchRadius: Double = 5000
    @Published var selectedLocation: GooglePlacesSearchPlaceWrapper? = nil
    @Published var searchQueries: [LocationSearchQuery] = []
    @Published var locationHistories: [GooglePlacesSearchPlaceWrapper] = []
    @Published var locationHistoriesOffset: Int = 0
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private var http: HttpClient = {
        let client = HttpClient(auth: HttpSupabaseAuthenticator(), retryPolicy: .exponentialBackoff(3, 4.5))
        return client
    }()
    private let logger = Logger.shared
    private let coreData = CoreDataStack.shared
    private var cancellable = Set<AnyCancellable>()
    private var isDataLoaded = false
    
    init() {
        self.userLocation = CoreDataStack.shared.fetch(String(describing: UserLocation.self))
        self.initializePlaceLIsts()
        self.loadGooglePlaceTypeList()
        self.searchQueries = self.getSearchQueries()
        self.authorizationStatus = UserLocationViewModel.shared.authorizationStatus ?? .notDetermined
        
        // Monitor network connection and location status arrival
        Publishers.CombineLatest(
            NetworkMonitor.shared.$isRealInternetReachable,
            UserLocationViewModel.shared.$status
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] reachable, status in
            // Update authorization status for UI
            self?.authorizationStatus = UserLocationViewModel.shared.authorizationStatus ?? .notDetermined
            
            if reachable && status == .available && !(self?.isDataLoaded ?? true) {
                Task { [weak self] in
                    await self?.startNetworkInitialization()
                }
            }
        }
        .store(in: &cancellable)
        
        NotificationCenter.default.addObserver(forName: .sendLocationNotification, object: nil, queue: .main) { notification in
            if let lastLocation = notification.userInfo?["lastLocation"] as? CLLocation {
                let location = UserLocation(
                    longitude: lastLocation.coordinate.longitude,
                    latitude: lastLocation.coordinate.latitude
                )
                Task { @MainActor in
                    self.userLocation = location
                }
            }
        }
    }
    
    @MainActor
    private func startNetworkInitialization() async {
        guard self.authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways else {
            return
        }
        self.fetchLocationHistory(offset: 0)
        await self.checkActiveRecruitment()
        await self.fetchActiveRecruitmentDetails()
        await self.searchSelectLocation()
        self.isDataLoaded = true
    }
    
    public func requestLocationPermission() {
        UserLocationViewModel.shared.requestPermission()
    }
}

extension LocationSelectViewModel {
    // MARK: Dummy wrapper for showing received data.
    private func makeDummyWrapper() -> GooglePlacesSearchPlaceWrapper {
        let wrapper: GooglePlacesSearchPlaceWrapper = .init()
        return wrapper
    }
    
    private func initializePlaceLIsts() {
        for _ in 0..<10 {
            let wrapper = self.makeDummyWrapper()
            self.famousPlaces.append(wrapper)
            self.livelyPlaces.append(wrapper)
            self.romanticPlaces.append(wrapper)
            self.naturalPlaces.append(wrapper)
            self.relaxedPlaces.append(wrapper)
        }
    }
}


extension LocationSelectViewModel {
    // MARK: - Nearby Search common methods.
    private func buildPlaceNearbySearchParamater(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        includedTypes: [GooglePlaceType],
        fieldMask mask: [GooglePlaceFieldMask],
        radius: Double,
        maxResultCount: Int,
        rankPreference: String = "POPULARITY",
        offset: Int = 0,
        limit: Int = 20
    ) async -> GooglePlacesNearbySearchParamater {
        let clientParam = await self.buildPlaceSearchClientParamater(latitude: latitude, longitude: longitude, offset: offset, limit: limit)
        let bodyParam = self.buildPlaceSearchBodyParamater(latitude: latitude,
                                                           longitude: longitude,
                                                           includedTypes: includedTypes,
                                                           radius: radius,
                                                           maxResultCount: maxResultCount,
                                                           rankPreference: rankPreference)
        
        // Field mask convert to appropriate data type.
        let fieldMask = mask.map({ "places.\($0.rawValue)" }).joined(separator: ",")
        let param = GooglePlacesNearbySearchParamater(requestParamater: bodyParam, fieldMask: fieldMask, clientParamater: clientParam)
        
        return param
    }
    
    @MainActor
    private func buildPlaceSearchClientParamater(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        offset: Int,
        limit: Int
    ) -> PlaceSearchClientParamater {
        // Cast zoom level into Integer
        let window = UIWindow()
        let windowSize = window.bounds.size
        let scale = window.screen.scale
        let clientParamater = PlaceSearchClientParamater(
            latitude: latitude,
            longitude: longitude,
            zoom: Int(self.zoom),
            windowSize: windowSize,
            scale: scale,
            offset: offset,
            limit: limit
        )
        return clientParamater
    }
    
    private func buildPlaceSearchBodyParamater(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        includedTypes: [GooglePlaceType],
        radius: Double,
        maxResultCount: Int,
        rankPreference: String
    ) -> GooglePlacesNearbySearchBodyParamater {
        // Make restriction
        let circle = LocationCircle(latitude: latitude, longitude: longitude, radius: radius)
        let restriction = LocationRestriction(circle: circle)
        
        // Make body paramater
        let body = GooglePlacesNearbySearchBodyParamater(includedTypes: includedTypes,
                                                         maxResultCount: maxResultCount,
                                                         languageCode: "ja",
                                                         rankPreference: rankPreference,
                                                         locationRestriction: restriction)
        
        return body
    }
    
    private func computeMaterPerPixel(latitude: CLLocationDegrees) -> Double {
        let latRadian = latitude / 180.0 * Double.pi
        let numerator = 2.0 * Double.pi * Double.WGS84_EQUATION_RADIUS
        let denominator = pow(2.0, Double(self.zoom)) * Double.TILE_SIZE
        
        return (numerator / denominator) * cos(latRadian)
    }
    
    
    @MainActor
    private func computeNearbySearchDefaultRadius(latitude: CLLocationDegrees) -> Double {
        // Compute radius
        let windowSize = UIWindow().bounds.size
        let maximumWindowSize = max(windowSize.width / 2, windowSize.height / 2) * UIScreen().scale
        let radius = maximumWindowSize * self.computeMaterPerPixel(latitude: latitude)
        
        return radius
    }
    
    private func nearbySearch(param: GooglePlacesNearbySearchParamater) async -> [GooglePlacesSearchPlaceWrapper] {
        do {
            let resp = try await http.post(url: .nearbySearch, content: param)
            if resp.ok {
                let places: [GooglePlacesSearchResponsePlace] = try resp.decode()
                return places.map({ GooglePlacesSearchPlaceWrapper(place: $0) })
            }
        } catch let error {
            logger.debug("Failed to nearby search: \(error.localizedDescription)")
        }
        
        return []
    }
    
    // MARK: - Nearby Search (Famous Location)
    public func searchFamousLocation(latitude: CLLocationDegrees, longitude: CLLocationDegrees) async -> [GooglePlacesSearchPlaceWrapper] {
        let placeTypes: [GooglePlaceType] = [.cafe, .restaurant, .amusementPark, .movieTheater, .artGallery, .park, .shoppingMall]
        let radius = await self.computeNearbySearchDefaultRadius(latitude: latitude)
        let param = await self.buildPlaceNearbySearchParamater(
            latitude: latitude,
            longitude: longitude,
            includedTypes: placeTypes,
            fieldMask: GooglePlaceFieldMask.defaultFieldMask,
            radius: radius,
            maxResultCount: 20
        )
        
        return await nearbySearch(param: param)
    }
    
    // MARK: - Nearby Search (Romantic Location)
    public func searchRomanticLocation(latitude: CLLocationDegrees, longitude: CLLocationDegrees) async -> [GooglePlacesSearchPlaceWrapper] {
        let placeTypes: [GooglePlaceType] = [.fineDiningRestaurant, .frenchRestaurant, .italianRestaurant, .wineBar]
        let radius = await self.computeNearbySearchDefaultRadius(latitude: latitude)
        let param = await self.buildPlaceNearbySearchParamater(
            latitude: latitude,
            longitude: longitude,
            includedTypes: placeTypes,
            fieldMask: GooglePlaceFieldMask.defaultFieldMask,
            radius: radius,
            maxResultCount: 10
        )
        
        return await nearbySearch(param: param)
    }
    
    // MARK: - Nearby Search (Relaxed Location)
    public func searchRelaxedLocation(latitude: CLLocationDegrees, longitude: CLLocationDegrees) async -> [GooglePlacesSearchPlaceWrapper] {
        let placeTypes: [GooglePlaceType] = [.artGallery, .museum, .cafe, .coffeeShop, .library, .bookStore, .spa]
        let radius = await self.computeNearbySearchDefaultRadius(latitude: latitude)
        let param = await self.buildPlaceNearbySearchParamater(
            latitude: latitude,
            longitude: longitude,
            includedTypes: placeTypes,
            fieldMask: GooglePlaceFieldMask.defaultFieldMask,
            radius: radius,
            maxResultCount: 10
        )
        
        return await nearbySearch(param: param)
    }
    
    // MARK: - Nearby Search (Lively Location)
    public func searchLivelyLocation(latitude: CLLocationDegrees, longitude: CLLocationDegrees) async  -> [GooglePlacesSearchPlaceWrapper] {
        let placeTypes: [GooglePlaceType] = [.amusementPark, .bar, .bowlingAlley, .amusementCenter]
        let radius = await self.computeNearbySearchDefaultRadius(latitude: latitude)
        let param = await self.buildPlaceNearbySearchParamater(
            latitude: latitude,
            longitude: longitude,
            includedTypes: placeTypes,
            fieldMask: GooglePlaceFieldMask.defaultFieldMask,
            radius: radius,
            maxResultCount: 10
        )
        
        return await nearbySearch(param: param)
    }
    
    // MARK: - Nearby Search (Natural Location)
    public func searchNaturalLocation(latitude: CLLocationDegrees, longitude: CLLocationDegrees) async -> [GooglePlacesSearchPlaceWrapper] {
        let placeTypes: [GooglePlaceType] = [.park, .aquarium, .zoo, .hikingArea, .campground, .botanicalGarden]
        let radius = await self.computeNearbySearchDefaultRadius(latitude: latitude)
        let param = await self.buildPlaceNearbySearchParamater(
            latitude: latitude,
            longitude: longitude,
            includedTypes: placeTypes,
            fieldMask: GooglePlaceFieldMask.defaultFieldMask,
            radius: radius,
            maxResultCount: 10
        )
        
        return await nearbySearch(param: param)
    }
    
    @MainActor
    public func searchSelectLocation() async {
         guard let latitude = self.userLocation?.latitude,
               let longitude = self.userLocation?.longitude else {
             self.logger.warning("⚠️ Skipping searchSelectLocation: User location is still unavailable.")
             return
         }
        
        async let famous = await self.searchFamousLocation(latitude: latitude, longitude: longitude)
        async let romantic = await self.searchRomanticLocation(latitude: latitude, longitude: longitude)
//        async let lively = await self.searchLivelyLocation(latitude: latitude, longitude: longitude)
//        async let relaxed = await self.searchRelaxedLocation(latitude: latitude, longitude: longitude)
//        async let natural = await self.searchNaturalLocation(latitude: latitude, longitude: longitude)
        
        // Waiting for all place data received.
        let (fam, rom, /*liv, rel, nat*/) = await (famous, romantic/* lively, relaxed, natural*/)
        
        self.famousPlaces = fam
        self.romanticPlaces = rom
//        self.livelyPlaces = liv
//        self.relaxedPlaces = rel
//        self.naturalPlaces = nat
        
    }
    
    // MARK: - Place detail.
    private func fetchPlaceDetail(
        _ wrapper: GooglePlacesSearchPlaceWrapper,
        fieldMask: [GooglePlaceFieldMask] = GooglePlaceFieldMask.detailFieldMask
    ) async -> GooglePlacesSearchPlaceWrapper? {
        guard let placeId = wrapper.place?.id else { return nil }
        let fieldMaskJoined = fieldMask.map({ $0.rawValue }).joined(separator: ",")
        let param = GooglePlacesPlaceDetailBodyParamater(fieldMask: fieldMaskJoined, placeIds: [placeId], languageCode: "ja")
        
        do {
            let resp = try await http.post(url: .getPlaceDetails, content: param)
            let place: [GooglePlacesSearchResponsePlace] = try resp.decode()
            return GooglePlacesSearchPlaceWrapper(place: place.first!)
        } catch let error {
            logger.error("Failed to fetch place detail: \(error.localizedDescription)")
            return nil
        }
    }
    
    @MainActor
    public func updatePlaceDetail() async {
        guard let wrapper = self.selectedPlace else { return }
        if let place = await self.fetchPlaceDetail(wrapper)?.place {
            if wrapper.place?.reviews == nil {
                self.selectedPlace?.place?.reviews = place.reviews
            }
            
            if wrapper.place?.currentOpeningHours == nil {
                self.selectedPlace?.place?.currentOpeningHours = place.currentOpeningHours
            }
            
            if wrapper.place?.websiteUri == nil {
                self.selectedPlace?.place?.websiteUri = place.websiteUri
            }
            
            if wrapper.place?.priceLevel == nil {
                self.selectedPlace?.place?.priceLevel = place.priceLevel
            }
            
            if wrapper.place?.priceRange == nil {
                self.selectedPlace?.place?.priceRange = place.priceRange
            }
            
            await self.updateNearestTransport()
        }
    }
    
    // MARK: - Search nearby transports
    private func searchNearbyTransports(latitude lat: CLLocationDegrees, longitude lon: CLLocationDegrees) async -> [GooglePlacesSearchPlaceWrapper] {
        let placeTypes: [GooglePlaceType] = [.trainStation, .subwayStation, .busStation, .airport, .ferryTerminal]
        let fieldMask: [GooglePlaceFieldMask] = [.id, .displayName, .location, .types]
        let param = await self.buildPlaceNearbySearchParamater(
            latitude: lat,
            longitude: lon,
            includedTypes: placeTypes,
            fieldMask: fieldMask,
            radius: 5000,
            maxResultCount: 10,
            rankPreference: "DISTANCE"
        )
        
        do {
            let response = try await http.post(url: .searchNearbyTransports, content: param)
            let places: [GooglePlacesSearchResponsePlace] = try response.decode()
            return places.map({ GooglePlacesSearchPlaceWrapper(place: $0) })
        } catch let error {
            self.logger.error("Failed to search nearby transports. \(error.localizedDescription)")
            return []
        }
    }
    
    private func fetchNearestTransport() async -> [GooglePlacesTransport] {
        guard let selectedPlace = self.selectedPlace?.place,
              let latitude = selectedPlace.location?.latitude,
              let longitude = selectedPlace.location?.longitude else { return [] }
        
        let places = await self.searchNearbyTransports(latitude: latitude, longitude: longitude)
        
        // Compute l2 distacne from selected place to nearest transports.
        let transports = places.compactMap({ wrapper in
            if let place = wrapper.place,
               let lat = place.location?.latitude,
               let lon = place.location?.longitude {
                let d = self.computeDistance(lat1: latitude, lon1: longitude, lat2: lat, lon2: lon)
                return GooglePlacesTransport(l2Distance: d, place: place)
            }
            
            return nil
        })
        
        return transports
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
    private func updateNearestTransport() async {
        self.nearestTransports.removeAll()
        
        // Fetch nearest transport.
        let transports = await self.fetchNearestTransport()
        
        self.nearestTransports = transports
    }
    
    // MARK: - Search nearby place in palce detail view.
    @MainActor
    public func textNearbySearch(_ query: String) async {
        guard let location = self.selectedPlace?.place?.location,
              let latitude = location.latitude,
              let longitude = location.longitude else { return }
        
        // Make request paramater.
        let locationCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let param = self.buildTextSearchRequestParamater(query: query, location: locationCoordinate, radius: 5000)
        
        do {
            let resp = try await http.post(url: .textSearch, content: param)
            let places: [GooglePlacesSearchResponsePlace] = try resp.decode()
            let placesWrapper = places.map({ GooglePlacesSearchPlaceWrapper(place: $0) })
            self.textSearchResults = placesWrapper
        } catch let error {
            logger.error("Failed to text search. \(error.localizedDescription)")
        }
    }
    
    private func buildTextSearchRequestParamater(
        query: String,
        location: CLLocationCoordinate2D? = nil,
        radius: Double,
        fieldMask: [GooglePlaceFieldMask] = [.id, .displayName, .formattedAddress, .location]
    ) -> GooglePlacesTextSearchParamater {
        var textSearchReqParam = GooglePlacesTextSearchRequestParamater(
            textQuery: query,
            languageCode: "ja",
            pageSize: 20
        )
        
        if let location = location {
            let circle = LocationCircle(latitude: location.latitude, longitude: location.longitude, radius: radius)
            textSearchReqParam.locationBias = .init(circle: circle)
        }
        
        let fieldMaskString = fieldMask.map({ "places.\($0.rawValue)" }).joined(separator: ",")
        let textSearchParam = GooglePlacesTextSearchParamater(fieldMask: fieldMaskString, requestParamater: textSearchReqParam)
        
        return textSearchParam
    }
    
    @MainActor
    public func addNearbyTextPlace(wrapper: GooglePlacesSearchPlaceWrapper) {
        guard !self.nearestLocations.contains(where: { $0.place.id == wrapper.place?.id }) else { return }
        guard let selectedPlace = self.selectedPlace,
              let location = selectedPlace.place?.location ,
              let locationLatitude = location.latitude,
              let locationLongitude = location.longitude else { return }
        guard let hitPlace = wrapper.place,
              let hitLocation = hitPlace.location,
              let hitLatitude = hitLocation.latitude,
              let hitLongitude = hitLocation.longitude else { return }
        
        let l2Distance = self.computeDistance(lat1: locationLatitude, lon1: locationLongitude, lat2: hitLatitude, lon2: hitLongitude)
        self.nearestLocations.append(.init(l2Distance: l2Distance, place: hitPlace))
        
        // Add selected nearest place in GMSMapView.
        Task {
            let fieldMask: [GooglePlaceFieldMask] = [.id, .location, .photos, .displayName, .formattedAddress]
            if let placeWrapper = await self.fetchPlaceDetail(wrapper, fieldMask: fieldMask) {
                if let hitIndex = self.nearestLocations.firstIndex(where: { $0.place.id == placeWrapper.place?.id }) {
                    self.nearestLocations[hitIndex].place.photos = placeWrapper.place?.photos
                    self.selectedNearestWrapper = .init(l2Distance: l2Distance, place: placeWrapper.place!)
                }
            }
        }
    }
    
    @MainActor
    public func tappedNearestPlaceMarker(latitude: Double, longitude: Double) {
        if let tappedLocation = self.nearestLocations.first(where: {
            $0.place.location?.latitude == latitude && $0.place.location?.longitude == longitude
        }) {
            self.selectedNearestWrapper = tappedLocation
        }
    }
    
    @MainActor
    public func addPlace() {
        guard let wrapper = self.selectedPlace else { return }
        guard !self.selectedCandidates.contains(where: { $0.place?.id == wrapper.place?.id }) else { return }
        self.selectedCandidates.append(wrapper)
    }

    @MainActor
    public func setSingleCandidate() {
        guard let wrapper = self.selectedPlace else { return }
        self.directRecruitmentPlace = wrapper
        if let id = wrapper.place?.id {
            self.recruitmentSelectedIds = [id]
        } else {
            self.recruitmentSelectedIds = []
        }
    }
    
    @MainActor
    public func prepareRecruitmentFromBox() {
        self.directRecruitmentPlace = nil
        self.recruitmentSelectedIds = Set(self.selectedCandidates.compactMap { $0.place?.id })
    }
    
    @MainActor
    public func removePlace() {
        guard let wrapper = self.selectedPlace else { return }
        self.selectedCandidates.removeAll(where: { $0.id == wrapper.id })
    }
    
    
    // MARK: - Recruitment editor
    @MainActor
    public func updateSelectedDate(date: Date) {
        let calendar = Calendar.current
        let startComp = calendar.compare(date, to: recruitmentStartDate, toGranularity: .day)
        
        if calendar.isDate(recruitmentStartDate, equalTo: recruitmentEndDate, toGranularity: .day) {
            if startComp == .orderedDescending {
                self.recruitmentEndDate = date
            } else {
                self.recruitmentStartDate = date
                self.recruitmentEndDate = date
            }
        } else {
            self.recruitmentStartDate = date
            self.recruitmentEndDate = date
        }
    }
    
    private func makeRecruitMessage() -> RecruitmentMessage {
        // Find tag character by regular expression.
        let regex = try? NSRegularExpression(pattern: "#[^\\s#]+", options: [])
        let matches = regex?.matches(in: messageText, range: NSRange(location: 0, length: messageText.count))
        
        var recruitMessage: RecruitmentMessage = .init(content: "", tags: [])
        var currentPosition = 0
        let nsMessageString = messageText as NSString
        
        for match in matches ?? [] {
            if let range = Range(match.range, in: messageText) {
                let tagString = messageText[range]
                recruitMessage.tags.append(String(tagString))
            }
            
            let gapRange = NSRange(location: currentPosition, length: match.range.length - currentPosition)
            if gapRange.length > 0 {
                let gapString = nsMessageString.substring(with: gapRange)
                recruitMessage.content.append(gapString)
            }
            
            currentPosition = match.range.location + match.range.length
        }
        
        if currentPosition < nsMessageString.length {
            let finalRange = NSRange(location: currentPosition, length: nsMessageString.length - currentPosition)
            let finalString  = nsMessageString.substring(with: finalRange)
            recruitMessage.content.append(finalString)
        }
        
        return recruitMessage
    }
    
    private func makeRecruitment(message: String) async -> Recruitment? {
        guard let session = await SupabaseManager.shared.getSession() else { return nil }
        
        // Expires date
        var expiresDate: Date = .now
        if self.dateType == .free {
            // If not decided expires date, it will be expired after 7 days.
            let calendar = Calendar.current
            expiresDate = calendar.date(byAdding: .day, value: 7, to: expiresDate)!
        } else {
            expiresDate = recruitmentEndDate
        }
        
        return .init(id: .init(),
                     uid: session.user.id,
                     message: message,
                     postDate: .now,
                     expiresDate: expiresDate,
                     viewCount: 0,
                     postUserAge: 20,
                     postUserSex: "man",
                     messageScore: 0.0,
                     status: .active
        )
    }
    
    @MainActor
    public func fetchActiveRecruitmentDetails() async {
        guard let recruitment = activeRecruitment else { return }
        self.isLoading = true
        defer { self.isLoading = false }
        
        do {
            if let details = await SupabaseManager.shared.selectRecruitment(recruitmentId: recruitment.id),
               let first = details.first {
                let placeIds = first.recruitmentPlaces?.compactMap({ $0.placeId }) ?? []
                let fieldMask: [GooglePlaceFieldMask] = [.id, .displayName, .formattedAddress, .photos, .rating]
                
                // Fetch details for each place
                var wrappers: [GooglePlacesSearchPlaceWrapper] = []
                for pid in placeIds {
                    let dummy = GooglePlacesSearchPlaceWrapper(place: .init(id: pid))
                    if let detail = await self.fetchPlaceDetail(dummy, fieldMask: fieldMask) {
                        wrappers.append(detail)
                    }
                }
                self.activeRecruitment = first.makeRecruitment()
                self.activeRecruitmentPlaces = wrappers
                self.messageText = self.activeRecruitment?.message ?? ""
            }
        }
    }

    @MainActor
    public func clearDraft() {
        self.messageText = ""
        self.selectedCandidates = []
        self.recruitmentSelectedIds = []
        self.recruitmentStartDate = .now
        self.recruitmentEndDate = .now
        self.dateType = .free
    }

    @MainActor
    public func updateActiveRecruitment(messageContent: String) async {
        guard let recruitmentId = activeRecruitment?.id else { return }
        self.isLoading = true
        defer { self.isLoading = false }
        
        do {
            try await SupabaseManager.shared.updateRecruitmentMessage(id: recruitmentId, message: messageContent)
            self.activeRecruitment?.message = messageContent
            logger.info("✅ Successfully updated recruitment message.")
        } catch {
            logger.error("❌ Failed to update recruitment message: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    public func closeActiveRecruitment() async {
        guard let recruitmentId = activeRecruitment?.id else { return }
        self.isLoading = true
        defer { self.isLoading = false }
        
        do {
            try await SupabaseManager.shared.closeRecruitment(id: recruitmentId)
            self.activeRecruitment = nil
            self.activeRecruitmentPlaces = []
            self.clearDraft()
            logger.info("✅ Successfully closed recruitment.")
        } catch {
            logger.error("❌ Failed to close recruitment: \(error.localizedDescription)")
        }
    }

    @MainActor
    public func checkActiveRecruitment() async {
        do {
            self.activeRecruitment = try await SupabaseManager.shared.checkMadeRecruitment()
            if self.activeRecruitment == nil {
                self.clearDraft()
            }
        } catch let error {
            self.logger.error("Failed to check active recruitment: \(error.localizedDescription)")
        }
    }

    @MainActor
    public func postRecruitment(completion: @escaping () -> ()) async {
        self.isLoading = true
        
        let recruitMessage = self.makeRecruitMessage()
    
        guard let recruitment = await self.makeRecruitment(message: recruitMessage.content) else { 
            self.isLoading = false
            return 
        }
        
        // Use direct spot if exists, otherwise use box
        let currentCandidates = self.directRecruitmentPlace != nil ? [self.directRecruitmentPlace!] : self.selectedCandidates
        
        // Filter candidates by selection
        let filteredCandidates = currentCandidates.filter { wrapper in
            if let id = wrapper.place?.id {
                return self.recruitmentSelectedIds.contains(id)
            }
            return false
        }
        
        let recruitmentPlaces: [RecruitmentPlace] = filteredCandidates.compactMap {
            if let placeId = $0.place?.id {
                return .init(id: recruitment.id, placeId: placeId)
            }
            return nil
        }
        let recruitmentHashTags: [RecruitmentHashTag] = recruitMessage.tags.compactMap({
            .init(id: recruitment.id, hashTag: $0)
        })
        let recruitmentPlaceTypes: [RecruitmentPlaceType] = filteredCandidates.compactMap({
            if let placeType = $0.place?.types?.first {
                return .init(id: recruitment.id, placeType: .init(rawValue: placeType))
            }
            return nil
        })
        
        do {
            let request = PostRecruitmentRequest(
                recruitment: recruitment,
                places: recruitmentPlaces,
                hashTags: recruitmentHashTags,
                placeTypes: recruitmentPlaceTypes
            )
            
            let response = try await self.http.post(url: .postRecruitment, content: request)
            if !response.ok {
                throw HttpError.unknownError
            }
     
            let spotHistories: [SpotHistory] = filteredCandidates.compactMap {
                if let placeId = $0.place?.id {
                    return .init(userId: recruitment.uid!, placeId: placeId, usedAt: .now)
                }
                return nil
            }
            
            if !spotHistories.isEmpty {
                try await SupabaseManager.shared.insertSpotHistories(histories: spotHistories)
            }

            self.activeRecruitment = recruitment
            await self.fetchActiveRecruitmentDetails()
            self.isLoading = false
            completion()
        } catch let error {
            self.isLoading = false
            self.logger.error("Failed to post recruitment: \(error.localizedDescription)")
        }
    }
}

// MARK: - Location Search
extension LocationSelectViewModel {
    private func loadGooglePlaceTypeList() {
        guard let contentPath = Bundle.main.path(forResource: "landmark_place_types", ofType: "csv") else { return }
        
        do {
            let content = try String(contentsOfFile: contentPath, encoding: .utf8)
            let rows = content.components(separatedBy: "\n")
            let data = rows.filter({ !$0.isEmpty }).map({ $0.components(separatedBy: ",") })
            var categories: [LocationCategory] = []
            
            for (i, row) in data.enumerated() {
                if i == 0 {
                    continue
                }
                
                let snakeName = row[1]
                let japaneseName = row[2]
                if let placeType = GooglePlaceType(rawValue: snakeName) {
                    categories.append(.init(name: japaneseName, placeType: placeType))
                }
            }
            
            self.locationCategories = categories
        } catch let error {
            self.logger.error("❌ Failed to load landmark place types: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    public func searchCatgory(query: String) -> [LocationCategory] {
        let hitCategories = self.locationCategories.filter({ $0.name.localizedStandardContains(query) })
        return hitCategories
    }
    
    @MainActor
    public func updateSelectedLocationCategories(category: LocationCategory) {
        if self.selectedLocationCategory.contains(where: { $0.id == category.id }) {
            self.selectedLocationCategory.removeAll(where: { $0.id == category.id })
        } else {
            guard self.selectedLocationCategory.count < 50 else { return }
            self.selectedLocationCategory.append(category)
        }
    }
    
    private func textSearch(param: GooglePlacesTextSearchParamater) async -> [GooglePlacesSearchPlaceWrapper] {
        do {
            let resp = try await self.http.post(url: .textSearch, content: param)
            if resp.ok {
                let places: [GooglePlacesSearchResponsePlace] = try resp.decode()
                return places.map({ GooglePlacesSearchPlaceWrapper(place: $0) })
            }
        } catch let error {
            self.logger.error("❌ Failed to text search: \(error.localizedDescription)")
        }
        return []
    }
    
    @MainActor
    public func locationSearch(query: String, offset: Int) async -> [GooglePlacesSearchPlaceWrapper] {
        // When use location search, consume 10 point
        
        let fieldMask: [GooglePlaceFieldMask] = [.id, .formattedAddress, .displayName, .photos, .location, .rating]
        if query.isEmpty {
            /// If no search query is entered, perform a search based on the category and the user's current location.
            guard let userLocation = self.userLocation else { return [] }
            var includedTypes = self.selectedLocationCategory.map({ $0.placeType })
            
            if includedTypes.isEmpty {
                let mustIncludedTypes: [GooglePlaceType] = [.cafe, .movieTheater, .restaurant, .amusementPark]
                includedTypes.append(contentsOf: mustIncludedTypes)
            }
            
            let nearbySearchParam = await self.buildPlaceNearbySearchParamater(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude,
                includedTypes: includedTypes,
                fieldMask: fieldMask,
                radius: self.searchRadius,
                maxResultCount: 20,
                offset: offset
            )
            let places = await self.nearbySearch(param: nearbySearchParam)
            
            NotificationCenter.default.post(name: .consumptionTotalPoint, object: nil, userInfo: ["consumption": 10])
            
            return places
        } else {
            self.pushSearchQuery(query: query)
            
            guard offset == 0 else { return [] }
            /// If a query is entered, a request is made to the Google Places API without specifying a location bias.
            let textSearchParam = self.buildTextSearchRequestParamater(query: query, radius: searchRadius, fieldMask: fieldMask)
            let places = await self.textSearch(param: textSearchParam)
            
            NotificationCenter.default.post(name: .consumptionTotalPoint, object: nil, userInfo: ["consumption": 10])
            
            return places
        }
    }
    
    public func selectedLocationMarker(wrapper: GooglePlacesSearchPlaceWrapper) {
        Task {
            await MainActor.run {
                if self.selectedLocation != nil {
                    self.selectedLocation = nil
                }
            }
            
            let fieldMask: [GooglePlaceFieldMask] = [.id, .displayName, .formattedAddress, .rating, .photos]
            let newDetail = await self.fetchPlaceDetail(wrapper, fieldMask: fieldMask)
            
            try? await Task.sleep(for: .seconds(0.3))
            await MainActor.run {
                self.selectedLocation = newDetail
            }
        }
    }
    
    public func getSearchQueries() -> [LocationSearchQuery] {
        let queries = self.coreData.getSearchQueries()
        return queries
    }
    
    @MainActor
    public func pushSearchQuery(query: String) {
        if let searchQuery = self.coreData.pushSearchQuery(query: query) {
            self.searchQueries.insert(searchQuery, at: 0)
            if self.searchQueries.count > 10 {
                self.searchQueries.removeLast()
            }
        }
    }
    
    @MainActor
    public func deleteSearchQuery(query: LocationSearchQuery) {
        self.searchQueries.removeAll(where: { $0.id == query.id })
        self.coreData.deleteSearchQuery(query: query)
    }
    
    public func fetchLocationHistory(offset: Int) {
        Task {
            do {
                let histories = try await SupabaseManager.shared.fetchLocationHistories(offset: offset)
                let placeIds = histories.compactMap({ $0.placeId })
                
                guard !placeIds.isEmpty else { return }
                
                let fieldMask: [GooglePlaceFieldMask] = [.id, .location, .photos, .rating, .displayName]
                let places = try await self.fetchPlaceDetails(placeIds: placeIds, fieldMask: fieldMask)
                
                await MainActor.run {
                    if offset == 0 {
                        self.locationHistories = places
                    } else {
                        self.locationHistories.append(contentsOf: places)
                    }
                }
            } catch let error {
                if let error = error as? HttpError {
                    self.logger.error("❌ Failed to fetch place details: \(error.errorDescription)")
                } else {
                    self.logger.error("❌ Failed to fetch place details: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func fetchPlaceDetails(placeIds: [String], fieldMask: [GooglePlaceFieldMask]) async throws -> [GooglePlacesSearchPlaceWrapper] {
        let fieldMaskString = fieldMask.map({ $0.rawValue }).joined(separator: ",")
        let param = GooglePlacesPlaceDetailBodyParamater(fieldMask: fieldMaskString, placeIds: placeIds)
        let resp = try await self.http.post(url: .getPlaceDetails, content: param)
        if resp.ok {
            let places: [GooglePlacesSearchResponsePlace] = try resp.decode()
            return places.map({ GooglePlacesSearchPlaceWrapper(place: $0) })
        }
        return []
    }
}
