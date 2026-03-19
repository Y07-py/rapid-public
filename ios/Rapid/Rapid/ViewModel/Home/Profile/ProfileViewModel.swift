//
//  ProfileViewModel.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/09/25.
//

import Foundation
import SwiftUI
import SDWebImage
import RevenueCat
import Combine

@MainActor
public class ProfileViewModel: ObservableObject {
    @Published var user: RapidUserWithProfile? = nil
    @Published var totalPoint: Int = 0
    @Published var introduction: String = ""
    @Published var height: Int = 140
    @Published var cityNames: [String: [City]] = [:]
    @Published var living: City?
    @Published var professions: [Profession] = []
    @Published var profession: Profession? = nil
    @Published var income: Income? = nil
    @Published var blood: BloodType? = nil
    @Published var smoking: Smoking? = nil
    @Published var drinking: Drinking? = nil
    @Published var child: ChildStatus? = nil
    @Published var mbtis: [MBTI] = []
    @Published var mbti: MBTI? = nil
    @Published var academicBackground: AcademicBackground? = nil
    @Published var thoughtMarriage: String = "未設定"
    @Published var holidayType: String = "未設定"
    @Published var bodyType: String = "未設定"
    
    // Subscription status
    @Published var currentPlanName: String = "無料会員"
    @Published var membershipStatus: String = "未加入"
    @Published var expirationDate: Date? = nil
    @Published var isPremium: Bool = false
    @Published var nextRenewalPrice: String? = nil
    
    // External accounts
    @Published var isAppleLinked: Bool = false
    @Published var isGoogleLinked: Bool = false
    @Published var isLineLinked: Bool = false
    
    // Profile images
    @Published var userProfileImages: [UserProfileImage] = []
    @Published var imagesToBeDeleted: [Int: UserProfileImage] = [:]
    @Published var tmpNewImages: [Int: UserProfileImage] = [:]
    
    // Notification messages
    @Published var unReadNotoficationMessageCount: Int = 0
    @Published var notificationMessages: [NotificationMessage] = []
    @Published var currentNotificationMessageOffset: Int = 0
    
    // Activity
    @Published var myRecruitments: [RecruitmentWithUserProfile] = []
    @Published var isLoadingActivity: Bool = false
    @Published var selectedActivity: RecruitmentWithUserProfile? = nil
    
    // Purchase History
    @Published var purchaseHistory: [NonSubscriptionTransaction] = []
    
    // Identification upload status
    @Published var isIdentificationUploading = false
    @Published var identificationUploadProgress: Double = 0
    @Published var identificationError: Error?
    @Published var identificationUploadSuccess = false
    
    public var hasChanges: Bool {
        guard let originalImages = user?.profileImages else { return !userProfileImages.isEmpty }
        
        // Check for deletions
        if !imagesToBeDeleted.isEmpty { return true }
        
        // Filter current editing images (excluding those marked for deletion)
        let effectiveImages = userProfileImages.filter { img in
            !imagesToBeDeleted.contains(where: { $0.value.id == img.id })
        }
        
        // Compare count
        if effectiveImages.count != originalImages.count { return true }
        
        // Compare individual image IDs and positions
        for (idx, img) in effectiveImages.enumerated() {
            if idx < originalImages.count {
                // If ID is different, it's either a different image or an edited one (new ID generated)
                if img.id != originalImages[idx].id {
                    return true
                }
            } else {
                return true
            }
        }
        
        return false
    }
    
    let incomes: [Income] = [
        .init(income: .under200),
        .init(income: .range200to400),
        .init(income: .range400to600),
        .init(income: .range600to800),
        .init(income: .range800to1000),
        .init(income: .over1000)
    ]
    let bloodTypes: [BloodType] = [
        .init(type: .A),
        .init(type: .B),
        .init(type: .AB),
        .init(type: .O)
    ]
    let smokings: [Smoking] = [
        .init(style: .none),
        .init(style: .oftentimes),
        .init(style: .sometimes)
    ]
    let drinkings: [Drinking] = [
        .init(style: .none),
        .init(style: .often),
        .init(style: .sometime)
    ]
    let childStatus: [ChildStatus] = [
        .init(status: .none),
        .init(status: .living)
    ]
    let academics: [AcademicBackground] = [
        .init(academic: .gradSchoolGraduate),
        .init(academic: .highSchoolGraduate),
        .init(academic: .universityGraduate),
        .init(academic: .other)
    ]
    let bodyTypes: [String] = ["未設定", "スリム", "やや細め", "普通", "グラマー", "筋肉質", "ややぽっちゃり", "ぽっちゃり"]
    let holidayTypes: [String] = ["未設定", "土日", "平日", "不定休", "その他"]
    let thoughtMarriages: [String] = ["未設定", "すぐにでも", "2〜3年内に", "いい人がいれば", "未定"]
    
    private var cancellables = Set<AnyCancellable>()
    private var isDataLoaded = false
    
    private let supabase = SupabaseManager.shared
    private let logger = Logger.shared
    private let http: HttpClient = {
        let client = HttpClient(auth: HttpSupabaseAuthenticator(), retryPolicy: .exponentialBackoff(3, 4.5))
        return client
    }()
    
    init() {
        loadCity()
        loadProfessionList()
        setupNotificationObservers()
        
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
    
    private func startNetworkInitialization() async {
        // Step1: Loading MBTI thumbnails
        await loadMBTIs()
        // Step2: Fetching external account status.
        await fetchExternalAccountStatus()
        // Step3: Fetching user profile.
        await fetchUserProfile()
        
        fetchSubscriptionStatus()
        fetchMessages()
        
        self.userProfileImages = self.user?.profileImages ?? []
        self.isDataLoaded = true
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: .receiveIntroductionModerateNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMessages()
                await self?.fetchUserProfile()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .receiveProfileImageReviewNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMessages()
                await self?.fetchUserProfile()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .receiveIdentityVerificationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMessages()
                await self?.fetchUserProfile()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .consumptionTotalPoint, object: nil, queue: .main) { notification in
            if let consumption = notification.userInfo?["consumption"] as? Int {
                Task { @MainActor in
                    guard self.totalPoint - consumption >= 0 else { return }
                    self.totalPoint -= consumption
                    await self.updateTotalPointToUsersTable()
                }
            }
        }
    }
}

extension ProfileViewModel {
    // MARK: initialize method
    public var isIdentityVerified: Bool {
        return user?.user.isIdentityVerified == true
    }
    
    private func fetchUserProfile() async {
        guard let session = await supabase.getSession() else { return }
        
        do {
            let rapidUser = try await supabase.fetchUser()
            let profileImages = await fetchProfileImages(userId: session.user.id)
            
            // Fetch under review images
            let underReviewImages = await fetchUnderReviewImages()
            var allProfileImages = profileImages
            allProfileImages.append(contentsOf: underReviewImages)
            
            self.user = .init(user: rapidUser, profileImages: allProfileImages)
            
            // Initialize published properties from fetched user data
            await MainActor.run {
                self.introduction = rapidUser.introduction ?? ""
                self.height = rapidUser.height ?? 170
                self.thoughtMarriage = rapidUser.thoughtMarriage ?? "未設定"
                self.holidayType = rapidUser.holidayType ?? "未設定"
                self.bodyType = rapidUser.bodyType ?? "未設定"
                
                // Map MBTI
                if let mbtiName = rapidUser.mbti {
                    self.mbti = self.mbtis.first(where: { $0.name == mbtiName })
                }
                
                // Map Residence
                if let residence = rapidUser.residence {
                    for pref in self.cityNames.keys {
                        if let city = self.cityNames[pref]?.first(where: { $0.cityName == residence }) {
                            self.living = city
                            break
                        }
                    }
                }
                
                // Map Profession
                if let profName = rapidUser.profession {
                    self.profession = self.professions.first(where: { $0.name == profName })
                }
                
                // Map Income
                if let incomeVal = rapidUser.income {
                    self.income = self.incomes.first(where: { $0.income.rawValue == incomeVal })
                }
                
                // Map Blood Type
                if let bloodVal = rapidUser.bloodType {
                    self.blood = self.bloodTypes.first(where: { $0.type.rawValue == bloodVal })
                }
                
                // Map Smoking
                if let smokingVal = rapidUser.smokingFrequency {
                    self.smoking = self.smokings.first(where: { $0.style.rawValue == smokingVal })
                }
                
                // Map Drinking
                if let drinkingVal = rapidUser.drinkingFrequency {
                    self.drinking = self.drinkings.first(where: { $0.style.rawValue == drinkingVal })
                }
                
                // Map Child Status
                if let childVal = rapidUser.childStatus {
                    self.child = self.childStatus.first(where: { $0.status.rawValue == childVal })
                }
                
                // Map Academic Background
                if let academicVal = rapidUser.academicBackground {
                    self.academicBackground = self.academics.first(where: { $0.academic.rawValue == academicVal })
                }
                
                // Total Point
                if let totalPoint = rapidUser.totalPoint {
                    self.totalPoint = totalPoint
                }
                
                // Sync UI images with the newly fetched user data
                self.syncProfileImagesWithServer()
            }
        } catch let error {
            logger.error("❌ Failed to fetch user profile. \(error.localizedDescription)")
        }
    }
    
    private func fetchProfileImages(userId: UUID) async -> [UserProfileImage] {
        do {
            let profileImages = try await supabase.fetchProfileImagesWithURLs(userId: userId)
            
            let urls = profileImages.compactMap { $0.imageURL }
            SDWebImagePrefetcher.shared.prefetchURLs(urls)
            
            return profileImages
        } catch let error {
            logger.error("❌ Failed to fetch profile images: \(error.localizedDescription)")
            return []
        }
    }
    
    private func fetchUnderReviewImages() async -> [UserProfileImage] {
        do {
            let response = try await self.http.get(url: .fetchUnderReviewMetadata)
            if response.ok {
                let session = await SupabaseManager.shared.getSession()
                let uploadProfileMetadatas: [UploadProfileImageMetaData] = try response.decode()
                return uploadProfileMetadatas.compactMap { metadata in
                    let imageURL = URL(string: .fetchUnderReviewImage + metadata.newImageId.uuidString.lowercased())!
                    return UserProfileImage(imageURL: imageURL, id: metadata.newImageId, isUnderReview: true, token: session?.accessToken)
                }
            }
        } catch let error {
            if let error = error as? HttpError {
                self.logger.error("❌ Failed to fetch under view images: \(error.errorDescription)")
            } else {
                self.logger.error("❌ Failed to fetch under review images: \(error.localizedDescription)")
            }
            return []
        }
        return []
    }
    
    private func fetchMBTIImages() async -> [String: URL] {
        do {
            let thumbnailURLs: [String: URL] = try await SupabaseManager.shared.getPresignURLFromStorage(bucket: "mbti", folder: "thumbnails")
            let urls = thumbnailURLs.map(\.value)
            SDWebImagePrefetcher.shared.prefetchURLs(urls)
            
            return thumbnailURLs
        } catch let error {
            logger.error("❌ Failed to fetch mbti thumbnail urls: \(error.localizedDescription)")
        }
        
        return [:]
    }
    
    private func loadCity() {
        guard let path = Bundle.main.path(forResource: "prefecture_cities_coordinates", ofType: "csv") else { return }
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let rows = content.components(separatedBy: "\r\n")
            let data = rows.map { $0.components(separatedBy: ",") }
            
            var cities: [String: [City]] = [:]
            for (i, row) in data.enumerated() {
                if i == 0 || row.count < 4 { continue }
                cities[row[0], default: []].append(City(
                    cityName: row[1],
                    prefName: row[0],
                    latitude: Double(row[2])!,
                    longitude: Double(row[3])!
                ))
            }
            self.living = (cities.first?.value.first!)!
            self.cityNames = cities
        } catch let error {
            logger.error("❌ Failed to load prefecture csv file. \(error.localizedDescription)")
        }
    }
    
    private func loadProfessionList() {
        guard let path = Bundle.main.path(forResource: "profession", ofType: "csv") else { return }
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let rows = content.components(separatedBy: "\n")
            let data = rows.map { $0.components(separatedBy: ",") }
            
            var loadProfessions: [Profession] = []
            for (i, row) in data.enumerated() {
                if i == 0 || row.count < 3 { continue }
                loadProfessions.append(Profession(category: row[1], name: row[2]))
            }
            
            self.professions = loadProfessions
        } catch let error {
            logger.error("❌ Failed to load profession csv file. \(error.localizedDescription)")
        }
    }
    
    private func loadMBTIs() async {
        let thumbnailURLs = await fetchMBTIImages()
        let mbtis = thumbnailURLs.map({ MBTI(name: $0.key.split(separator: ".")[0].uppercased(), thumbnailURL: $0.value) })
        self.mbtis = mbtis
    }
    
    public func updateProfile() async {
        guard let session = await SupabaseManager.shared.getSession() else { return }
        let userModel = RapidUser(
            id: session.user.id,
            userName: user?.user.userName,
            birthDate: user?.user.birthDate,
            residence: living?.cityName,
            thoughtMarriage: thoughtMarriage == "未設定" ? nil : thoughtMarriage,
            bloodType: blood?.type.rawValue,
            academicBackground: academicBackground?.academic.rawValue,
            income: income?.income.rawValue,
            profession: profession?.name,
            drinkingFrequency: drinking?.style.rawValue,
            smokingFrequency: smoking?.style.rawValue,
            childStatus: child?.status.rawValue,
            height: height,
            mbti: mbti?.name,
            settingStatus: true,
            introduction: introduction,
            holidayType: holidayType == "未設定" ? nil : holidayType,
            sex: user?.user.sex,
            bodyType: bodyType == "未設定" ? nil : bodyType,
            subscriptionStatus: user?.user.subscriptionStatus,
            totalPoint: user?.user.totalPoint
        )
        
        do {
            // Update via backend proxy to allow for post-processing/scoring
            let response = try await self.http.post(url: .updateProfileMetadata, content: userModel)
            if response.ok {
                let newUser: RapidUserWithProfile = .init(user: userModel, profileImages: self.user?.profileImages ?? [])
                self.user = newUser
                self.logger.info("✅ Successfully updated userprofile via proxy.")
            }
        } catch let error {
            if let error = error as? HttpError {
                self.logger.error("❌ Failed to upload user profile metadata: \(error.errorDescription)")
            }
        }
    }
}

// MARK: - Subscription
extension ProfileViewModel {
    @MainActor
    public func restorePurchases(completion: @escaping (Bool) -> Void) {
        Purchases.shared.restorePurchases { customerInfo, error in
            if let error = error {
                self.logger.error("❌ Failed to restore purchases. \(error.localizedDescription)")
                completion(false)
                return
            }
            
            self.updateSubscriptionInfo(customerInfo)
            
            if let entitlements = customerInfo?.entitlements,
               let premium = entitlements["Rapid Premium"],
               premium.isActive {
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    @MainActor
    public func fetchSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in
            guard let self = self else { return }
            if let error = error {
                self.logger.error("❌ Failed to fetch customer info. \(error.localizedDescription)")
                return
            }
            self.updateSubscriptionInfo(customerInfo)
        }
    }
    
    @MainActor
    private func updateSubscriptionInfo(_ customerInfo: CustomerInfo?) {
        guard let customerInfo = customerInfo else { return }
        
        if let entitlement = customerInfo.entitlements["Rapid Premium"], entitlement.isActive {
            self.isPremium = true
            self.currentPlanName = "プレミアムプラン" 
            
            if entitlement.willRenew {
                self.membershipStatus = "有効"
            } else {
                self.membershipStatus = "解約予約済み"
            }
            self.expirationDate = entitlement.expirationDate
            
            // Try to find the price
            Purchases.shared.getOfferings { offerings, error in
                if let package = offerings?.current?.availablePackages.first(where: { $0.storeProduct.productIdentifier == entitlement.productIdentifier }) {
                    DispatchQueue.main.async {
                        self.nextRenewalPrice = package.localizedPriceString
                    }
                }
            }
        } else {
            self.isPremium = false
            self.currentPlanName = "無料会員"
            self.membershipStatus = "未加入"
            self.expirationDate = nil
            self.nextRenewalPrice = nil
        }
    }
    
    @MainActor
    public func fetchPurchaseHistory() {
        Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in
            guard let self = self, let customerInfo = customerInfo else { return }
            self.purchaseHistory = customerInfo.nonSubscriptionTransactions.sorted(by: { $0.purchaseDate > $1.purchaseDate })
        }
    }
    
    @MainActor
    public func fetchExternalAccountStatus() async {
        guard let session = await supabase.getSession() else { return }
        let identities = session.user.identities ?? []
        
        self.isAppleLinked = identities.contains(where: { $0.provider == "apple" })
        self.isGoogleLinked = identities.contains(where: { $0.provider == "google" })
        self.isLineLinked = identities.contains(where: { $0.provider == "line" })
    }
    
    
    // MARK: - Profile image setting
    @MainActor
    public func updateProfileImage(idx: Int, image: UserProfileImage) {
        if idx < self.userProfileImages.count {
            self.userProfileImages[idx] = image
        } else {
            self.userProfileImages.append(image)
        }
        self.tmpNewImages[idx] = image
    }
    
    func syncProfileImagesWithServer() {
        guard let serverProfileImages = self.user?.profileImages else { return }
        
        for serverImage in serverProfileImages {
            // Find existing image with the same ID in the UI state
            if let index = self.userProfileImages.firstIndex(where: { $0.id == serverImage.id }) {
                // Update the existing image with the latest server data (e.g., status or URL)
                // This surgical update helps avoid UI flickering and unnecessary reloads
                self.userProfileImages[index] = serverImage
            } else {
                // Add new images from server that aren't yet in the UI state
                self.userProfileImages.append(serverImage)
            }
        }
        
        // Remove images that are no longer on the server, while keeping local-only ones (e.g., currently uploading)
        self.userProfileImages.removeAll { local in
            local.image == nil && !serverProfileImages.contains(where: { $0.id == local.id })
        }
    }
    
    @MainActor
    public func uploadProfileImages() {
        Task {
            guard let user = self.user else { return }
            
            // 1. Identify which images should effectively be in the profile now
            let effectiveImages = userProfileImages.filter { img in
                !imagesToBeDeleted.values.contains(where: { $0.id == img.id })
            }
            
            // 2. Identify images to completely remove (present in server but not in effective list)
            let trulyDeletedImages = user.profileImages.filter { serverImg in
                !effectiveImages.contains(where: { $0.id == serverImg.id })
            }
            
            if !trulyDeletedImages.isEmpty {
                do {
                    try await self.supabase.deleteProfileImages(deleteImage: trulyDeletedImages)
                    self.logger.info("✅ Successfully deleted \(trulyDeletedImages.count) images from server.")
                } catch {
                    self.logger.error("❌ Failed to delete images from server: \(error.localizedDescription)")
                }
            }
            
            // 3. Prepare metadata and uploads
            var uploadProfileImageList: [UploadProfileImage] = []
            
            for (displayIdx, image) in effectiveImages.enumerated() {
                let existingInServer = user.profileImages.first(where: { $0.id == image.id })
                let isNew = image.image != nil
                let indexChanged = existingInServer != nil && user.profileImages.firstIndex(where: { $0.id == image.id }) != displayIdx
                
                // If the image is new OR its index has changed, we need to update metadata
                if isNew || indexChanged {
                    let oldImage = displayIdx < user.profileImages.count ? user.profileImages[displayIdx] : nil
                    
                    uploadProfileImageList.append(.init(
                        userId: user.user.id,
                        oldImage: oldImage,
                        newImage: image,
                        safeStatus: .check,
                        imageIndex: displayIdx,
                        uploadAt: .now
                    ))
                }
            }
            
            // Clear temporary states locally after determining changes
            self.imagesToBeDeleted.removeAll()
            self.tmpNewImages.removeAll()

            // If no images have changed or being uploaded, we are done
            if uploadProfileImageList.isEmpty { 
                await fetchUserProfile()
                return 
            }
            
            do {
                // Split media data and text data.
                let uploadMetadata = uploadProfileImageList.map({ UploadProfileImageMetaData(
                    userId: $0.userId,
                    oldImageId: $0.oldImage?.id,
                    newImageId: $0.newImage.id,
                    safeStatus: $0.safeStatus,
                    imageIndex: $0.imageIndex,
                    uploadAt: $0.uploadAt)
                })
                
                // Call backend to save metadata
                let metadataRequest = UploadProfileImageMetaDataRequest(metadata: uploadMetadata)
                let response = try await self.http.post(url: .uploadProfileImageMetadata, content: metadataRequest)
                if response.ok {
                    for item in uploadProfileImageList {
                        guard let imageData = item.newImage.image else { continue }
                        let imageId = item.newImage.id
                        
                        let metadata = ["newImageId": imageId.uuidString.lowercased()]
                        let stream = try await self.http.tusUpload(
                            url: .uploadImage,
                            metadata: metadata,
                            content: imageData
                        )
                        
                        do {
                            for try await event in stream {
                                switch event {
                                case .started:
                                    self.logger.info("🚀 TUS upload started for \(imageId)")
                                case .progress(let bytesUpload, let totalBytes):
                                    let progress = Double(bytesUpload) / Double(totalBytes)
                                    self.logger.info("⏳ TUS upload progress for \(imageId): \(Int(progress * 100))%")
                                case .finished(let url):
                                    self.logger.info("✅ TUS upload finished for \(imageId): \(url)")
                                    
                                    // 1. Update the editing state (local array)
                                    if let idx = self.userProfileImages.firstIndex(where: { $0.id == imageId }) {
                                        self.userProfileImages[idx].isUnderReview = true
                                        let updatedImage = self.userProfileImages[idx]
                                        
                                        // Update user profile image in main thread.
                                        await MainActor.run {
                                            guard var currentUser = self.user else { return }
                                            if let userIdx = currentUser.profileImages.firstIndex(where: { $0.id == imageId }) {
                                                currentUser.profileImages[userIdx] = updatedImage
                                            } else {
                                                currentUser.profileImages.append(updatedImage)
                                            }
                                            self.user = currentUser
                                            self.syncProfileImagesWithServer()
                                        }
                                    }
                                }
                            }
                        } catch let error {
                            self.logger.error("❌ TUS upload failed for \(imageId): \(error.localizedDescription)")
                        }
                    }
                    
                    // Final refresh after all uploads are processed
                    await fetchUserProfile()
                }
            } catch let error {
                if let error = error as? HttpError {
                    self.logger.error("❌ Failed to upload profile image: \(error.errorDescription)")
                } else {
                    self.logger.error("❌ Failed to upload profile image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @MainActor
    public func refreshWhenDisappear() {
        guard let user = user else { return }
        // Revert userProfileImages to the stable server state
        self.userProfileImages = user.profileImages
        
        // Clear all temporary editing states
        self.tmpNewImages.removeAll()
        self.imagesToBeDeleted.removeAll()
    }
    
    // MARK: - Mail box
    @MainActor
    public func fetchMessages() {
        Task {
            do {
                let offset = self.currentNotificationMessageOffset
                let rawMessages = try await self.supabase.fetchNotificationMessages(offset: offset)
                
                // Filter out voice chat related notifications using messageType for robustness
                let filteredMessages = rawMessages.filter { !$0.messageType.hasPrefix("voice_chat") }
                
                // Avoid duplicates if refreshing
                if offset == 0 {
                    self.notificationMessages = filteredMessages
                } else {
                    self.notificationMessages.append(contentsOf: filteredMessages)
                }
                
                let unreadCount = self.notificationMessages.count(where: { !$0.isRead })
                self.unReadNotoficationMessageCount = unreadCount
                
                // IMPORTANT: Increase offset by the number of RAW messages fetched from DB
                // to maintain correct pagination even when some items are filtered out.
                self.currentNotificationMessageOffset += rawMessages.count
            } catch let error {
                self.logger.error("❌ Failed to fetch messages: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    public func refreshMessages() {
        self.currentNotificationMessageOffset = 0
        self.fetchMessages()
    }
    
    @MainActor
    public func updateMessage() {
        Task {
            do {
                let messages = self.notificationMessages
                try await self.supabase.updateNotificationMessages(messages: messages)
            } catch let error {
                self.logger.error("❌ Failed to update messages: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    public func addPoints(_ amount: Int) async {
        self.totalPoint += amount
        // Update both local user model and database
        if var user = self.user {
            user.user.addPoint(point: amount)
            self.user = user
        }
        await updateTotalPointToUsersTable()
    }
    
    private func updateTotalPointToUsersTable() async {
        do {
            try await self.supabase.updateTotalPointToUsersTable(totalPoint: totalPoint)
        } catch let error {
            self.logger.error("❌ Failed update total point: \(error.localizedDescription)")
        }
    }
}

// MARK: - Check actitivity
extension ProfileViewModel {
    @MainActor
    public func fetchActivity() {
        self.isLoadingActivity = true
        Task {
            defer { self.isLoadingActivity = false }
            do {
                let recruitmentRelations = try await self.supabase.fetchMyRecruitments(offset: 0)
                
                // Fetch current user (myself)
                guard let currentUser = self.user else { return }
                
                let processedRecruitments = try await withThrowingTaskGroup(of: RecruitmentWithUserProfile.self) { group in
                    var results: [RecruitmentWithUserProfile] = []
                    
                    for recRel in recruitmentRelations {
                        group.addTask {
                            let placeIds = recRel.recruitmentPlaces?.compactMap({ $0.placeId }) ?? []
                            let places = try await self.fetchPlaceDetail(placeIds: placeIds)
                            let placesWrapper = places.map({ GooglePlacesSearchPlaceWrapper(place: $0) })
                            
                            // RecruitmentWithLike needs a RecruitmentWithRelations
                            let recWithLike = RecruitmentWithLike(like: nil, recruitmentWithRelations: recRel)
                            
                            return RecruitmentWithUserProfile(
                                profile: currentUser,
                                places: placesWrapper,
                                recruitment: recWithLike
                            )
                        }
                    }
                    
                    for try await result in group {
                        results.append(result)
                    }
                    return results.sorted(by: { 
                        ($0.recruitment.recruitmentWithRelations.postDate ?? .distantPast) > 
                        ($1.recruitment.recruitmentWithRelations.postDate ?? .distantPast) 
                    })
                }
                
                self.myRecruitments = processedRecruitments
            } catch let error {
                self.logger.error("❌ Failed to fetch activity: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchPlaceDetail(placeIds: [String]) async throws -> [GooglePlacesSearchResponsePlace] {
        if placeIds.isEmpty { return [] }
        let fieldMask = GooglePlaceFieldMask.detailFieldMask
            .map({ $0.rawValue }).joined(separator: ",")
        let param = GooglePlacesPlaceDetailBodyParamater(fieldMask: fieldMask, placeIds: placeIds, languageCode: "ja")
        
        let resp = try await http.post(url: .getPlaceDetails, content: param)
        let placeDetails: [GooglePlacesSearchResponsePlace] = try resp.decode()
        
        return placeDetails
    }
}

// MARK: - Identification
extension ProfileViewModel {
    @MainActor
    func uploadIdentificationImage(image: UIImage, idType: IdentificationType, guideFrame: CGRect) async -> Bool {
        isIdentificationUploading = true
        identificationUploadSuccess = false
        identificationUploadProgress = 0
        self.identificationError = nil
        
        defer { isIdentificationUploading = false }
        
        // 1. Crop Image
        let viewSize = UIWindow().bounds.size
        guard let croppedImage = image.crop(to: guideFrame, in: viewSize) else {
            self.identificationError = HttpError.unknownError
            return false
        }
        
        guard let imageData = croppedImage.jpegData(compressionQuality: 0.8) else {
            self.identificationError = HttpError.unknownError
            return false
        }
        
        do {
            guard let session = await supabase.getSession() else { return false }
            
            // 2. Prepare Metadata
            let newImageId = UUID()
            let metadata = UploadIdentityVerificationMetaData(
                id: UUID(),
                userId: session.user.id,
                newImageId: newImageId,
                identificationType: idType.rawValue,
                internalPath: nil,
                uploadAt: Date()
            )
            
            // 3. Post Metadata to Proxy
            let response = try await http.post(
                url: .uploadIdentityVerificationMetadata,
                content: UploadIdentityVerificationMetaDataRequest(metadata: metadata)
            )
            
            if response.ok {
                // 4. Tus Upload
                let stream = try await http.tusUpload(
                    url: .uploadImage,
                    metadata: ["newImageId": newImageId.uuidString],
                    content: imageData
                )
                
                for try await event in stream {
                    switch event {
                    case .progress(let bytesUpload, let totalBytes):
                        self.identificationUploadProgress = Double(bytesUpload) / Double(totalBytes)
                    case .finished(_):
                        self.identificationUploadSuccess = true
                        return true
                    case .started:
                        break
                    }
                }
            }
        } catch {
            self.identificationError = error
            return false
        }
        
        return false
    }
    
    @MainActor
    public func rePost(recruitment: RecruitmentWithUserProfile, completion: @escaping (Bool) -> Void) {
        Task {
            // Check whether posting something recruitment
            do {
                if let _ = try await self.supabase.checkMadeRecruitment() {
                    completion(false)
                } else {
                    let newRecruitmentId = UUID()
                    let now = Date()
                    let expiresAt = Calendar.current.date(byAdding: .hour, value: 24, to: now)!
                    
                    let originalRec = recruitment.recruitment.recruitmentWithRelations
                    
                    let newRecruitment = Recruitment(
                        id: newRecruitmentId,
                        uid: originalRec.userId,
                        message: originalRec.message,
                        postDate: now,
                        expiresDate: expiresAt,
                        viewCount: 0,
                        postUserAge: originalRec.postUserAge,
                        postUserSex: originalRec.postUserSex,
                        messageScore: nil,
                        status: .active
                    )
                    
                    let newPlaces = (originalRec.recruitmentPlaces ?? []).map {
                        RecruitmentPlace(id: newRecruitmentId, placeId: $0.placeId)
                    }
                    
                    let newHashTags = (originalRec.recruitmentHashTags ?? []).map {
                        RecruitmentHashTag(id: newRecruitmentId, hashTag: $0.hashTag)
                    }
                    
                    let newPlaceTypes = (originalRec.recruitmentPlaceTypes ?? []).map {
                        RecruitmentPlaceType(id: newRecruitmentId, placeType: $0.placeType)
                    }
                    
                    let request = PostRecruitmentRequest(
                        recruitment: newRecruitment,
                        places: newPlaces,
                        hashTags: newHashTags,
                        placeTypes: newPlaceTypes
                    )
                    
                    let response = try await self.http.post(url: .postRecruitment, content: request)
                    if response.ok {
                        self.fetchActivity()
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            } catch let error {
                self.logger.error("❌ Failed to post recruitment: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    @MainActor
    public func postInquiryMessage(type: String, message: String, completion: @escaping (Bool) -> Void) {
        Task {
            guard let session = await self.supabase.getSession() else {
                completion(false)
                return
            }
            let inquiryMessage = InquiryMessage(userId: session.user.id, type: type, message: message, sendDate: .now)
            do {
                let response = try await self.http.post(url: .postInquiryMessage, content: inquiryMessage)
                if response.ok {
                    completion(true)
                }
            } catch let error {
                if let error = error as? HttpError {
                    self.logger.error("❌ Failed to post inquiry message: \(error.errorDescription)")
                } else {
                    self.logger.error("❌ Failed to post inquiry message: \(error.localizedDescription)")
                }
                completion(false)
            }
        }
    }
}
