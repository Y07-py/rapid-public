//
//  ProfileSettingViewModel.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/12.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import Supabase

class ProfileLoginSettingViewModel: ObservableObject {
    @Published var progress = 0.0
    @Published var userName: String = ""
    @Published var birthday: Date = .init()
    @Published var height: Int = 145
    @Published var selectedPrefecture: Prefecture? = nil {
        didSet {
            // Reset selected city when prefecture changes
            selectedCity = nil
        }
    }
    @Published var selectedCity: City? = nil
    @Published var selectedBloodType: BloodType? = nil
    @Published var selectedSmokingStyle: Smoking? = nil
    @Published var selectedAcademicBackground: AcademicBackground? = nil
    @Published var selectedAnnualIncome: Income? = nil
    @Published var selectedProfession: Profession? = nil
    @Published var selectedPurpose: MatchingPurpose? = nil
    @Published var selectedDrink: Drinking? = nil
    @Published var selectedChildStatus: ChildStatus? = nil
    @Published var introduction: String = ""
    @Published var selectedImages: [UIImage] = []
    
    @Published var cityList: [String: [City]] = [:]
    
    // Keyword tags.
    @Published var keywordTags: [String: [KeyWordTag]] = [:]
    @Published var selectedKeyWordTags: [KeyWordTag] = []
    
    // Sex selection
    @Published var selectedGender: Sex? = nil
    let sexList: [Sex] = [.init(type: .man), .init(type: .woman)]
    
    // Spot and Recruitment
    @Published var nearbySpots: [GooglePlacesSearchResponsePlace] = []
    @Published var isLoadingSpots: Bool = false
    @Published var selectedSpot: GooglePlacesSearchPlaceWrapper? = nil
    @Published var recruitmentMessage: String = ""
    
    @Published var isProcessing: Bool = false
    @Published var didComplete: Bool = false
    
    private let logger = Logger.shared
    private let http: HttpClient = {
        let client = HttpClient(auth: HttpSupabaseAuthenticator(), retryPolicy: .exponentialBackoff(3, 4.5))
        return client
    }()
    
    @Published var prefectureList: [Prefecture] = []
    let bloodTypeList: [BloodType] = [.init(type: .A), .init(type: .B), .init(type: .AB), .init(type: .O)]
    let smokingStyleList: [Smoking] = [.init(style: .none), .init(style: .sometimes), .init(style: .oftentimes)]
    let academicBackgroundList: [AcademicBackground] = [.init(academic: .highSchoolGraduate), .init(academic: .universityGraduate), .init(academic: .gradSchoolGraduate)]
    let annualIncomeList: [Income] = [
        .init(income: .under200),
        .init(income: .range200to400),
        .init(income: .range400to600),
        .init(income: .range600to800),
        .init(income: .over1000),
    ]
    let professionList: [Profession] = []
    let matchingPurposeList: [MatchingPurpose] = [
        .init(purpose: .dating),
        .init(purpose: .friendship),
        .init(purpose: .hobbyFriend),
        .init(purpose: .penFriend),
        .init(purpose: .seriousRelationship),
        .init(purpose: .other)
    ]
    let drinkingList: [Drinking] = [
        .init(style: .none),
        .init(style: .sometime),
        .init(style: .often)
    ]
    let childStatusList: [ChildStatus] = [
        .init(status: .living),
        .init(status: .none)
    ]
    
    init() {
        Task { @MainActor in
            initializePrefectureList()
            await fetchKeyWordTags()
        }
    }
}

extension ProfileLoginSettingViewModel {
    @MainActor
    private func initializePrefectureList() {
        guard let path = Bundle.main.path(forResource: "prefecture_cities_coordinates", ofType: "csv") else { return }
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            var prefectures: [Prefecture] = []
            var cities: [String: [City]] = [:]
            var seenNames = Set<String>()
            var code = 1
            
            for line in lines.dropFirst() {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty { continue }
                let components = trimmedLine.components(separatedBy: ",")
                if components.count >= 4 {
                    let prefName = components[0].trimmingCharacters(in: .whitespaces)
                    let cityName = components[1].trimmingCharacters(in: .whitespaces)
                    let lon = Double(components[2].trimmingCharacters(in: .whitespaces)) ?? 0.0
                    let lat = Double(components[3].trimmingCharacters(in: .whitespaces)) ?? 0.0
                    
                    // Prefecture list
                    if !prefName.isEmpty && !seenNames.contains(prefName) {
                        prefectures.append(.init(code: code, name: prefName))
                        seenNames.insert(prefName)
                        code += 1
                    }
                    
                    // City list organized by prefecture
                    let city = City(cityName: cityName, prefName: prefName, latitude: lat, longitude: lon)
                    cities[prefName, default: []].append(city)
                }
            }
            self.prefectureList = prefectures
            self.cityList = cities
        } catch let error {
            logger.error("❌ Failed to read prefcode file: \(error)")
        }
    }
    
    @MainActor
    public func toggleKeyWordTag(tag: KeyWordTag) {
        if let index = self.selectedKeyWordTags.firstIndex(where: { $0.keyword == tag.keyword }) {
            self.selectedKeyWordTags.remove(at: index)
        } else {
            self.selectedKeyWordTags.append(tag)
        }
    }
    
    @MainActor
    public func fetchKeyWordTags() async {
        do {
            let keywords = try await SupabaseManager.shared.fetchKeyWordTags()
            var newTags: [String: [KeyWordTag]] = [:]
            for keyword in keywords {
                newTags[keyword.category, default: []].append(keyword)
            }
            self.keywordTags = newTags
        } catch let error {
            self.logger.error("❌ Failed to fetch keyword tags: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    public func loginComplete() async {
        self.isProcessing = true
        await self.uploadProfile()
        await self.postRecruitment()
        self.isProcessing = false
        self.didComplete = true
    }
    
    @MainActor
    private func postRecruitment() async {
        guard let spot = self.selectedSpot else { return }
        
        let recruitMessage = self.makeRecruitMessage()
        
        guard let recruitment = await self.makeRecruitment(message: recruitMessage.content) else { return }
        
        let recruitmentPlaces: [RecruitmentPlace] = [
            .init(id: recruitment.id, placeId: spot.place?.id)
        ]
        
        let recruitmentHashTags: [RecruitmentHashTag] = recruitMessage.tags.compactMap({
            .init(id: recruitment.id, hashTag: $0)
        })
        
        let recruitmentPlaceTypes: [RecruitmentPlaceType] = [
            spot.place?.types?.first.map { .init(id: recruitment.id, placeType: GooglePlaceType(rawValue: $0)) }
        ].compactMap { $0 }
        
        do {
            try await SupabaseManager.shared.postRecruitment(
                recruitment: recruitment,
                places: recruitmentPlaces,
                placeTypes: recruitmentPlaceTypes,
                tags: recruitmentHashTags
            )
            
            if let placeId = spot.place?.id, let uid = recruitment.uid {
                let spotHistory = SpotHistory(userId: uid, placeId: placeId, usedAt: .now)
                try await SupabaseManager.shared.insertSpotHistories(histories: [spotHistory])
            }
            
            self.logger.info("✅ Successfully posted recruitment during profile setting.")
        } catch let error {
            self.logger.error("❌ Failed to post recruitment: \(error.localizedDescription)")
        }
    }
    
    private func makeRecruitMessage() -> RecruitmentMessage {
        // Find tag character by regular expression.
        let regex = try? NSRegularExpression(pattern: "#[^\\s#]+", options: [])
        let matches = regex?.matches(in: recruitmentMessage, range: NSRange(location: 0, length: recruitmentMessage.count))
        
        var recruitMessage: RecruitmentMessage = .init(content: "", tags: [])
        var currentPosition = 0
        let nsMessageString = recruitmentMessage as NSString
        
        for match in matches ?? [] {
            if let range = Range(match.range, in: recruitmentMessage) {
                let tagString = recruitmentMessage[range]
                recruitMessage.tags.append(String(tagString))
            }
            
            let gapRange = NSRange(location: currentPosition, length: match.range.location - currentPosition)
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
        
        // Default expires date: after 7 days
        let calendar = Calendar.current
        let expiresDate = calendar.date(byAdding: .day, value: 7, to: .now)!
        
        return .init(id: .init(),
                     uid: session.user.id,
                     message: message,
                     postDate: .now,
                     expiresDate: expiresDate,
                     viewCount: 0,
                     postUserAge: birthday.computeAge(),
                     postUserSex: selectedGender?.type.dbValue ?? "man", 
                     messageScore: 0.0,
                     status: .active
        )
    }
    
    @MainActor
    private func uploadProfile() async {
        // upload inputted profile to supabse, and insert `users` table
        guard let session = await SupabaseManager.shared.getSession() else { return }
        let residence = (selectedCity?.prefName ?? "未設定") + " " + (selectedCity?.cityName ?? "")
        let profileModel = RapidUser(
            id: session.user.id,
            userName: userName,
            birthDate: birthday,
            residence: residence,
            height: height,
            settingStatus: true,
            introduction: introduction,
            sex: selectedGender?.type.dbValue,
            subscriptionStatus: "free",
            totalPoint: 100,
            isIdentityVerified: false
        )
        let keywordTags = self.selectedKeyWordTags.map({ keyword in
            var updated = keyword
            updated.userId = session.user.id
            return updated
        })
        let images = self.selectedImages
        
        do {
            let profileMetaData = UploadProfileMetaData(user: profileModel, keywords: keywordTags)
            // Upload profile
            let response = try await self.http.post(url: .uploadProfile, content: profileMetaData)
            if response.ok {
                // Upload profile image
                await self.uploadProfileImage(session: session, images: images)
                self.logger.info("✅ Successfully uploaded profile and keywords.")
            }
        } catch let error {
            if let httpError = error as? HttpError {
                self.logger.error("❌ Failed to upload profile: \(httpError.errorDescription)")
            } else {
                self.logger.error("❌ Failed to upload profile: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadProfileImage(session: Session, images: [UIImage]) async {
        let uploadProfileImages = images.enumerated().map { (index, uiImage) in
            let profileImage = UserProfileImage(image: uiImage)
            return UploadProfileImage(userId: session.user.id, newImage: profileImage, safeStatus: .check, imageIndex: index, uploadAt: .now)
        }
        let uploadProfileImageMetaData = uploadProfileImages.map({
            UploadProfileImageMetaData(userId: $0.userId, newImageId: $0.newImage.id, safeStatus: $0.safeStatus, imageIndex: $0.imageIndex, uploadAt: $0.uploadAt)
        })
        let metaDataRequest = UploadProfileImageMetaDataRequest(metadata: uploadProfileImageMetaData)
        
        do {
            let response = try await self.http.post(url: .uploadProfileImageMetadata, content: metaDataRequest)
            if response.ok {
                for item in uploadProfileImages {
                    guard let imageData = item.newImage.image else { continue }
                    let imageId = item.newImage.id.uuidString.lowercased()
                    let metaData = ["newImageId": imageId]
                    let stream = try await self.http.tusUpload(url: .uploadImage, metadata: metaData, content: imageData)
                    
                    for try await event in stream {
                        switch event {
                        case .started:
                            self.logger.info("🚀 TUS upload started for \(imageId)")
                        case .progress(let bytesUpload, let totalBytes):
                            let progress = Double(bytesUpload) / Double(totalBytes)
                            self.logger.info("⏳ TUS upload progress for \(imageId): \(Int(progress * 100))%")
                        case .finished(let url):
                            self.logger.info("✅ TUS upload finished for \(imageId): \(url)")
                        }
                    }
                }
            }
        } catch let error {
            if let error = error as? HttpError {
                self.logger.error("❌ Failed to upload profile image. \(error.errorDescription)")
            } else {
                self.logger.error("❌ Failed to upload profile image. \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    public func fetchNearbySpots() async {
        guard let location = UserLocationViewModel.shared.location else { return }
        
        self.isLoadingSpots = true
        defer { self.isLoadingSpots = false }
        
        let placeTypes: [GooglePlaceType] = [.cafe, .coffeeShop, .dessertShop, .bar, .amusementCenter]
        let fieldMask: [GooglePlaceFieldMask] = [.id, .displayName, .location, .types, .formattedAddress, .photos, .rating]
        
        let body = GooglePlacesNearbySearchBodyParamater(
            includedTypes: placeTypes,
            maxResultCount: 20,
            languageCode: "ja",
            rankPreference: "POPULARITY",
            locationRestriction: .init(circle: .init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, radius: 20000))
        )
        
        let fieldMaskString = fieldMask.map({ "places.\($0.rawValue)" }).joined(separator: ",")
        
        // Use a dummy window size for client paramater
        let clientParam = PlaceSearchClientParamater(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            zoom: 13,
            windowSize: CGSize(width: 375, height: 812), // iPhone 13 dummy size
            scale: 3.0
        )
        
        let param = GooglePlacesNearbySearchParamater(requestParamater: body, fieldMask: fieldMaskString, clientParamater: clientParam)
        
        do {
            let response = try await http.post(url: .nearbySearch, content: param)
            if response.ok {
                let places: [GooglePlacesSearchResponsePlace] = try response.decode()
                self.nearbySpots = places
            }
        } catch let error {
            self.logger.error("❌ Failed to fetch nearby spots: \(error.localizedDescription)")
        }
    }
}
