//
//  SupabaseManager.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/07.
//

import Foundation
import Supabase
import os
import PhoneNumberKit
import UIKit
import CoreGraphics
import Combine

enum AuthError: LocalizedError {
    case emptyEmail
    case invalidEmail
    case networkError
    case unknownError
    case invalidOTP
    case invalidPhoneNumber
    case emptyPhoneNumber
    case googleSignInFailed(Error)
    case verifyOTPFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .emptyEmail:
            return "メールアドレスが入力されていません。"
        case .invalidEmail:
            return "無効なメールアドレスです。"
        case .networkError:
            return "ネットワークエラーが発生しました。"
        case .unknownError:
            return "不明なエラーが発生しました。"
        case .invalidOTP:
            return "無効なOTPコードです。"
        case .invalidPhoneNumber:
            return "無効な携帯番号です。"
        case .emptyPhoneNumber:
            return "携帯番号が入力されていません。"
        case .googleSignInFailed(let error):
            return "Failed to sign in with Google: \(error.localizedDescription)"
        case .verifyOTPFailed(let error):
            return "Failed to verify with OTP: \(error.localizedDescription)"
        }
    }
}

final class SupabaseManager {
    static let shared = SupabaseManager()
    private var client: SupabaseClient!
    
    private let logger = Logger.shared
    private let coreData = CoreDataStack.shared
    private let phoneNumberUtiity = PhoneNumberUtility()
    private var tempolaryDeviceToken: String? = nil

    private var httpClient: HttpClient = {
        let client = HttpClient(retryPolicy: .exponentialBackoff(3, 4.5))
        return client
    }()
    
    private init() {}
   
    public func initialize() {
        let supabaseKey: String = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as! String
        let urlString: String = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_BASE_URL") as! String
       
        self.client = SupabaseClient(
          supabaseURL: URL(string: urlString)!,
          supabaseKey: supabaseKey,
          options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
          )
        )
        
        self.logger.info("✅ Successfully initialized SupabaseClient.")
        
        // Listen for auth changes to register FCM token
        Task {
            for await (event, session) in client.auth.authStateChanges {
                self.logger.info("🔔 Auth state changed: \(String(describing: event))")
                if let _ = session {
                    if event == .signedIn || event == .initialSession || event == .tokenRefreshed {
                        self.registFCMPayload()
                    }
                }
            }
        }
    }
    
    public func currentSession() -> Session? {
        return self.client.auth.currentSession
    }
   
    public func checkSession() async -> Bool {
        do {
            let session = try await self.client.auth.session
            
            let userMetaData = session.user.userMetadata
            let emailVerified = userMetaData["email_verified"]?.value as? Bool ?? false
            let phoneVerified = userMetaData["phone_verified"]?.value as? Bool ?? false
            
            if emailVerified || phoneVerified {
                let userModel = try await fetchUser()
                if userModel.settingStatus {
                    return true
                }
            }
            
            return false
        } catch let error {
            logger.info("user is not logged in yet. \(error.localizedDescription)")
            return false
        }
    }

    public func checkExistingSessionStatus() async -> LoginSessionStatus {
        guard let session = await getSession() else {
            return .noSession
        }
        
        do {
            let userModel = try await fetchUser(id: session.user.id)
            if userModel.settingStatus {
                return .completed
            } else {
                return .profileIncomplete
            }
        } catch {
            // User record doesn't exist yet, but authenticated.
            return .profileIncomplete
        }
    }
    
    public func signOut() async {
        do {
            try await self.client.auth.signOut()
        } catch let error {
            self.logger.error("Failed sign out. \(error.localizedDescription)")
        }
    }
    
    public func checkEmailExist(_ email: String) async -> Bool {
        do {
            let status: EmailCheckStatus = try await self.client.functions.invoke(
                "email_exist",
                options: FunctionInvokeOptions(body: ["email": email])
            )
            
            return status.exists
        } catch let error {
            logger.error("Failed to check email exist: \(error.localizedDescription)")
            return false
        }
    }
    
    public func signInOtpWithEmail(_ email: String) async throws {
        if email.isEmpty {
            logger.warning("⚠️ enterd email address is empty.")
            throw AuthError.emptyEmail
        }
        
        if !isValidEmail(email) {
            logger.warning("⚠️ enterd email address is invalid.")
            throw AuthError.invalidEmail
        }
        
        try await self.client.auth.signInWithOTP(email: email, shouldCreateUser: true)
    }
    
    public func signInOtpwithPhoneNumber(_ phoneNumber: String, country: Country) async throws {
        if phoneNumber.isEmpty {
            logger.warning("⚠️ enterd phone number is empty.")
            throw AuthError.emptyPhoneNumber
        }
        
        if let parseNumber = isValidPhoneNumber(phoneNumber, country: country) {
            try await self.client.auth.signInWithOTP(phone: parseNumber, shouldCreateUser: true)
        } else {
            logger.warning("⚠️ enterd phone number is invalid.")
            throw AuthError.invalidPhoneNumber
        }
    }
    
    public func signInWithGoogle(idToken: String, accessToken: String) async throws {
        do {
            let response = try await self.client.auth.signInWithIdToken(credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken,
                nonce: nil
            ))
            try await registUser(session: response)
        } catch let error {
            throw AuthError.googleSignInFailed(error)
        }
    }
    
    public func signInWithAuth0(jwt: String, accessToken: String) async throws {
        let response = try await self.client.auth.signInWithIdToken(credentials: .init(
            provider: .init(rawValue: "auth0")!,
            idToken: jwt,
            accessToken: accessToken
        ))
        try await registUser(session: response)
    }
    
    public func signInWithApple(idToken: String, nonce: String) async throws {
        let response = try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
        try await registUser(session: response)
    }
    
    public func verifyOtpWithEmail(email: String, otp: String) async throws {
        if otp.count < 6 {
            logger.warning("⚠️ otp length is less than 6.")
            throw AuthError.invalidOTP
        }
        
        let response =  try await self.client.auth.verifyOTP(email: email, token: otp, type: .email)
        try await registUser(session: response.session)
    }
    
    public func verifyOtpWithPhoneNumber(phoneNumber: String, otp: String) async throws {
        if otp.count < 6 {
            logger.warning("⚠️ otp length is less than 6.")
            throw AuthError.invalidOTP
        }
        
        let response = try await self.client.auth.verifyOTP(phone: phoneNumber, token: otp, type: .sms)
        try await registUser(session: response.session)
    }
    
    public func insertUserModel(_ user: inout UserModel) async throws {
        try await insertUserProfile(user.profile)
        try await insertKeyWordTags(user.keywordTags)
        let urls = try await uploadProfileImages(user.profileImages)
        
        urls?.forEach { key, url in
            guard let index = user.profileImages.firstIndex(where: { $0.id.uuidString == key }) else { return }
            user.profileImages[index].imageURL = url
        }
        
        coreData.save(user)
    }
    
    private func insertUserProfile(_ userProfile: UserProfile) async throws {
        try await client
            .from("UserProfile")
            .insert(userProfile)
            .select()
            .execute()
            .value
    }
    
    public func selectUserProfile(_ uid: String) async throws -> UserProfile? {
        let profile: [UserProfile] = try await client
            .from("UserProfile")
            .select()
            .eq("uid", value: uid)
            .execute()
            .value
        
        return profile.first
    }
    
    private func insertKeyWordTags(_ keyWordTags: [UserProfileKeyWordTag]) async throws {
        try await client
            .from("KeyWordTag")
            .insert(keyWordTags)
            .execute()
    }
    
    public func insertIosDeviceToken(_ token: DeviceToken) async throws {
        try await client
            .from("ios_device_tokens")
            .insert(token)
            .execute()
    }
    
    private func triggerEdgeFunction<T: Codable>(name: String, body: T) async throws {
        guard let session = await getSession() else { return }
        try await client.functions
            .invoke(name, options: FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(session.accessToken)"],
                body: body
            ))
    }
    
    private func uploadProfileImages(
        _ profileImages: [UserProfileImage],
        bucket: String = "profile",
        folder: String = "users",
        upsert: Bool = false,
        createSignedURL: Bool = true,
        expiresIn: Int = 24 * 60 * 60,
        maxConcurrency: Int = 6,
    ) async throws -> [String: URL]? {
        let semaphore = DispatchSemaphore(value: maxConcurrency)
        guard let uid = await getSession()?.user.id.uuidString else { return nil }
        
        let filePaths: [String] = try await withThrowingTaskGroup(of: String.self) { group in
            for profile in profileImages {
                group.addTask {
                    defer { semaphore.signal() }
                    do {
                        let filename = "\(uid)/\(profile.id.uuidString.lowercased()).jpg"
                        let key = try await self.uploadProfileImageOne(
                            bucket: bucket,
                            folder: folder,
                            data: profile.image!,
                            fileName: filename,
                        )
                        return key
                    } catch let error {
                        self.logger.error("❌ Failed to upload profile image.: \(error.localizedDescription)")
                        fatalError(error.localizedDescription)
                    }
                }
            }
            
            var paths: [String] = []
            for try await key in group {
                paths.append(key)
            }
            
            return paths
        }
        
        if createSignedURL {
            let urls: [String: URL] = try await withThrowingTaskGroup(of: (String, URL).self) { group in
                for (image, path) in zip(profileImages, filePaths) {
                    group.addTask {
                        let url = try await self.client
                            .storage
                            .from(bucket)
                            .createSignedURL(path: path, expiresIn: expiresIn)
                        return (image.id.uuidString, url)
                    }
                }
                var tmpURLs: [String: URL] = [:]
                for try await (id, url) in group {
                    tmpURLs[id] = url
                }
                return tmpURLs
            }
            return urls
        }
        
        return nil
    }
    
    private func uploadProfileImageOne(
        bucket: String,
        folder: String,
        data: Data,
        fileName: String,
    ) async throws -> String {
        let filePath = folder.isEmpty ? fileName : "\(folder)/\(fileName)"
        try await client
            .storage
            .from(bucket)
            .upload(
                filePath,
                data: data
            )
        return filePath
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailTest.evaluate(with: email)
    }
    
    private func isValidPhoneNumber(_ phoneNumber: String, country: Country) -> String? {
        do {
            let parseNumber = try phoneNumberUtiity.parse(phoneNumber, withRegion: country.region)
            let e164Number = phoneNumberUtiity.format(parseNumber, toType: .e164)
            
            return e164Number
        } catch {
            return nil
        }
    }
    
    func getSession() async -> Session? {
        do {
            return try await client.auth.session
        } catch let error {
            logger.warning("⚠️ Failed to get session: \(error.localizedDescription)")
            return nil
        }
    }
    
    public func getAllRowsFromTable<T: Codable>(
        table: String,
        eqColumn: String = "",
        eqValue: String = "",
        pageSize: Int = 100,
        orderBy:String = "id",
        ascending: Bool = true
    ) async throws -> [T] {
        var allRows: [T] = []
        var offset: Int = 0
        
        while true {
            let from = offset
            let to = offset + pageSize - 1
            
            let page: [T] = try await client
                .from(table)
                .select()
                .eq(eqColumn, value: eqValue)
                .order(orderBy, ascending: ascending)
                .range(from: from, to: to)
                .execute()
                .value
            
            if page.isEmpty { break }
            allRows += page
            offset += page.count
            
            if page.count < pageSize { break }
        }
        
        return allRows
    }
    
    public func getAllRowsFromTable<T: Codable>(
        table: String,
        cols: [String: String],
        eqKey: String = "",
        eqValue: PostgrestFilterValue = "",
        pageSize: Int = 100,
        orderBy:String = "id",
        ascending: Bool = true
    ) async throws -> [T] {
        var allRows: [T] = []
        var offset: Int = 0
        let orQuery = cols.compactMap({ "\($0.key).eq.\($0.value)"}).joined(separator: ",")
        
        while true {
            let from = offset
            let to = offset + pageSize - 1
            
            let page: [T] = try await client
                .from(table)
                .select()
                .or(orQuery)
                .eq(eqKey, value: eqValue)
                .order(orderBy, ascending: ascending)
                .range(from: from, to: to)
                .execute()
                .value
            
            if page.isEmpty { break }
            allRows += page
            offset += page.count
            
            if page.count < pageSize { break }
        }
        
        return allRows
    }
    
    public func getPresignURLFromStorage(bucket: String, folder: String? = nil, expiresIn: Int = 60 * 60 * 24) async throws -> [String: URL] {
        let files = try await client
            .storage
            .from(bucket)
            .list(path: folder)
        
        return try await withThrowingTaskGroup(of: (String, URL).self) { group in
            files.forEach { file in
                group.addTask {
                    let path: String
                    if let folder = folder {
                        path = folder + "/\(file.name)"
                    } else {
                        path = file.name
                    }
                    
                    let url = try await self.client
                        .storage
                        .from(bucket)
                        .createSignedURL(path: path, expiresIn: expiresIn)
                    return (file.name, url)
                }
            }
            
            var urls: [String: URL] = [:]
            for try await (id, url) in group {
                urls[id] = url
            }
            return urls
        }
    }
    
    public func getSignedURLs(bucket: String, paths: [String], expiresIn: Int = 24 * 60 * 60) async throws -> [String: URL] {
        return try await withThrowingTaskGroup(of: (String, URL).self) { group in
            for path in paths {
                group.addTask {
                    let cleanPath = path.hasPrefix("\(bucket)/") ? path.replacingOccurrences(of: "\(bucket)/", with: "") : path
                    let url = try await self.client
                        .storage
                        .from(bucket)
                        .createSignedURL(path: cleanPath, expiresIn: expiresIn)
                    return (path, url) // Use the original path as key
                }
            }
            
            var urls: [String: URL] = [:]
            for try await (path, url) in group {
                urls[path] = url
            }
            return urls
        }
    }
    
    public func getSinglePresignURLFromStorage(bucket: String, path: String, expiresIn: Int = 60 * 24 * 24) async throws -> URL {
        return try await self.client
            .storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: expiresIn)
    }
    
    private func registUser(session: Session?) async throws {
        if let session = session {
            try await self.recordAuthDetails(session: session)
        }
    }
    
    private func recordAuthDetails(session: Session) async throws {
        let user = session.user
        
        // 1. Ensure user record exists in 'users' table first
        do {
            _ = try await fetchUser(id: user.id)
        } catch {
            // If missing, create initial record
            let initialUser = RapidUser(
                id: user.id,
                settingStatus: false,
                subscriptionStatus: "free",
                totalPoint: 100
            )
            try await self.client
                .from("users")
                .insert(initialUser)
                .execute()
            self.logger.info("✅ Created initial record in users table for \(user.id) with 'free' status and 100 points.")
        }
        
        // 2. Prepare authentication details for 'user_authentications' table
        let provider = try user.appMetadata["provider"]?.decode(as: String.self, decoder: JSONDecoder())
        let authDetails = UserAuthentication(
            userId: user.id,
            createdAt: user.createdAt,
            lastSignInAt: user.lastSignInAt,
            email: user.email,
            phoneNumber: user.phone,
            provider: provider
        )
        
        // 3. Upsert into 'user_authentications'
        try await self.client
            .from("user_authentications")
            .upsert(authDetails)
            .execute()
        self.logger.info("✅ Recorded/Updated authentication details for \(user.id) with provider \(provider ?? "unknown")")
    }
    
    public func fetchUser(id: UUID? = nil) async throws -> RapidUser {
        let userId: UUID
        if let id = id {
            userId = id
        } else {
            guard let session = await getSession() else { fatalError("Failed to fetch current user.") }
            userId = session.user.id
        }
        
        let userModel: RapidUser = try await self.client
            .from("users")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
        
        return userModel
    }
    
    public func fetchKeyWordTags() async throws -> [KeyWordTag] {
        let keywordTags: [KeyWordTag] = try await self.client
            .from("keyword_tags")
            .select()
            .execute()
            .value
        
        return keywordTags
    }
    
    public func updateRow(table: String, colKey: String, colValue: String, eqKey: String, eqValue: String) async throws {
        try await client
            .from(table)
            .update([colKey: colValue])
            .eq(eqKey, value: eqValue)
            .execute()
    }
    
    public func uploadProfile(profile: RapidUser, keywordTags: [KeyWordTag], images: [UIImage]) async throws {
        let profileImages = images.map({ UserProfileImage(image: $0) })
        
        let _ = try await self.uploadProfileImages(profileImages)
        try await self.client
            .from("users")
            .upsert(profile)
            .execute()
        
        let keywordTags = keywordTags.map({ keyword in
            KeyWordTag(id: keyword.id, userId: profile.id, keyword: keyword.keyword, category: keyword.category)
        })
        
        if !keywordTags.isEmpty {
            try await self.client
                .from("user_keyword_tags")
                .insert(keywordTags)
                .execute()
        }
    }
    
    public func updateProfile(profile: RapidUser) async throws {
        try await client
            .from("users")
            .update(profile)
            .eq("user_id", value: profile.id)
            .execute()
    }
    
    public func registFCMPayload() {
        guard let fcmToken = UserDefaults.standard.string(forKey: "last_fcm_token"),
              let session = self.currentSession() else {
            self.logger.info("ℹ️ Skipping FCM registration: Token or Session not ready.")
            return
        }
        
        let payload = FCMPayload(
            fcmToken: fcmToken,
            deviceType: "ios",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            deviceModel: UIDevice.current.model
        )
        
        Task {
            // Wait for real internet reachability
            while !NetworkMonitor.shared.isRealInternetReachable {
                try? await Task.sleep(nanoseconds: 1 * 1_000_000_000) // retry check every 1s
            }
            
            let auth = HttpSupabaseAuthenticator()
            auth.setToken(token: session.accessToken, expiresIn: session.expiresIn)
            
            do {
                let _ = try await httpClient
                    .setAuth(httpAuth: auth)
                    .post(url: .registFcmPayload, content: payload)
                self.logger.info("✅ Successfully to regist fcm payload.")
            } catch let error {
                if let httpError = error as? HttpError {
                    self.logger.error("❌ Failed to post fcm payload: \(httpError.errorDescription)")
                } else {
                    self.logger.error("❌ Failed to post fcm payload: \(error.localizedDescription)")
                }
            }
        }
    }
}

extension SupabaseManager {
    public func getAccessToken() async throws -> String {
        guard let session = await getSession() else {
            throw SupabaseError.notSignIn("Failed to get session. may be you need to sign in.")
        }
        
        return session.accessToken
    }
    
    public func checkExistUser(userId: UUID) async throws -> Bool {
        let users: [RapidUser] = try await self.client
            .from("users")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return users.count == 1
    }
}

// MARK: fetch like paor
extension SupabaseManager {
    public func selectLikePairs(userId: String) async throws -> [LikePair] {
        let likePairs: [LikePair] = try await self.client
            .from("like_pairs")
            .select()
            .eq("to_user_id", value: userId)
            .eq("matched", value: false)
            .execute()
            .value
        
        return likePairs
    }

    public func checkExistLikePair(fromUserId: UUID, toUserId: UUID) async throws -> LikePair? {
        let likePairs: [LikePair] = try await self.client
            .from("like_pairs")
            .select()
            .eq("from_user_id", value: fromUserId)
            .eq("to_user_id", value: toUserId)
            .execute()
            .value
        return likePairs.first
    }
    
    public func updateLikePairsReadStatus(ids: [UUID]) async throws {
        try await self.client
            .from("like_pairs")
            .update(["is_read": true])
            .in("id", values: ids)
            .execute()
    }
    
    public func selectBlockedUsers() async throws -> [BlockedUser] {
        guard let session = await self.getSession() else { return [] }
        let blockedUsers: [BlockedUser] = try await self.client
            .from("blocked_users")
            .select("*")
            .eq("user_id", value: session.user.id)
            .execute()
            .value
        
        return blockedUsers
    }
}

// MARK: chat message
extension SupabaseManager {
    public func subscribeChatChannel(roomId: UUID) async throws -> SupabaseSubscription {
        let channel = client.channel("realtime:messages:chat_\(roomId.uuidString)")
        let subscription = channel
            .onPostgresChange(
                InsertAction.self,
                schema: "public",
                table: "chat_messages",
                filter: "room_id=eq.\(roomId.uuidString.lowercased())"
            ) { action in
                NotificationCenter.default.post(name: .insertMessageNotification, object: nil, userInfo: ["action": action])
            }
        try await channel.subscribeWithError()
        
        return SupabaseSubscription(id: roomId, channel: channel, subscription: subscription)
    }
    
    public func insertMessage(message: ChatMessage) async throws {
        try await client
            .from("messages")
            .insert(message)
            .execute()
    }
    
    public func buildPresignedImageURLForChatMessage(chatId: UUID, fileName: String, expiresIn: Int = 3600) async throws -> URL {
        let presignedURL = try await client
            .storage
            .from("chat")
            .createSignedURL(path: "\(chatId.uuidString)/\(fileName)", expiresIn: 3600)

        return presignedURL
    }

    public func uploadMessageImage(
        roomId: UUID,
        messageId: UUID,
        image: UIImage,
        maxSize: Int = 5 * (1 << 20)
    ) async throws -> AsyncThrowingStream<HttpUploadEvent, Error> {
        guard var imageData = image.jpegData(compressionQuality: 1.0) else { fatalError("Failed to convert image to jpeg data") }
        let dataSize = Double(imageData.count)
        if dataSize > Double(maxSize) {
            guard let (_, quality) = jpegDataFitting(image, maxSize: maxSize) else { fatalError("Failed to find appropriate compression ratio") }
            guard let newImageData = image.jpegData(compressionQuality: quality) else { fatalError("Failed to convert image to jpeg data") }
            imageData = newImageData
        }

        let objectName = "\(roomId.uuidString.lowercased())/\(messageId.uuidString.lowercased()).jpeg"
        let metaDataHeader = uploadMetaData(bucketName: "message", objectName: objectName, contentType: "image/jpeg")
        let headers: [String: String] = [
            "x-upsert": "true",
            "Upload-Metadata": metaDataHeader
        ]
        
        return try await httpClient
            .setAuth(httpAuth: HttpSupabaseAuthenticator())
            .tusUpload(url: .reusableEndPoint, headers: headers, content: imageData)
    }

    public func buildPresignedURLForMessageImage(roomId: UUID, messageId: UUID, expiresIn: Int = 3600) async throws -> URL {
        let path = "\(roomId.uuidString.lowercased())/\(messageId.uuidString.lowercased()).jpeg"
        let presignedURL = try await client
            .storage
            .from("message")
            .createSignedURL(path: path, expiresIn: expiresIn)

        return presignedURL
    }
    
    public func uploadImageMessge(
        chatId: UUID,
        fileName: String,
        image: UIImage,
        maxSize: Int = 5 * (1 << 20)
    ) async throws -> AsyncThrowingStream<HttpUploadEvent, Error> {
        // find appropriate compression ratio.
        guard var imageData = image.jpegData(compressionQuality: 1.0) else { fatalError("Failed to convert image to jpeg data") }
        let dataSize = Double(imageData.count)
        if dataSize > Double(maxSize) {
            guard let (_, quality) = jpegDataFitting(image, maxSize: maxSize) else { fatalError("Failed to find appropriate compression ratio") }
            guard let newImageData = image.jpegData(compressionQuality: quality) else { fatalError("Failed to convery image to jpeg data") }
            imageData = newImageData
        }
        
        let metaDataHeader = uploadMetaData(bucketName: "chat", objectName: "\(chatId.uuidString)/\(fileName)", contentType: "image/jpeg")
        let headers: [String: String] = [
            "x-upsert": "true",
            "Upload-Metadata": metaDataHeader
        ]
        
        return try await httpClient.tusUpload(url: .reusableEndPoint, headers: headers, content: imageData)
    }
    
    private func uploadMetaData(
        bucketName: String,
        objectName: String,
        contentType: String,
        cacheControl: String = "3600",
        userMetadataJSON: String? = nil
    ) -> String {
        var pairs: [String] = [
            "bucketName \(bucketName.b64())",
            "objectName \(objectName.b64())",
            "contentType \(contentType.b64())",
            "cacheControl \(cacheControl.b64())"
        ]
        
        if let json = userMetadataJSON {
            pairs.append("metadata \(json.b64())")
        }
        
        return pairs.joined(separator: ",")
    }
    
    private func jpegDataFitting(_ image: UIImage,
                         maxSize: Int,
                         initialHigh: CGFloat = 1.0,
                         initialLow: CGFloat = 0.4,
                         minQuality: CGFloat = 0.1,
                         toleranceRatio: CGFloat = 0.03,
                         maxIters: Int = 7) -> (data: Data, quality: CGFloat)? {
        ///  This function for calculating the maxium compression ratio that does not exceed maxSize when converting images to JPEG.
        ///  and also, the unit for `maxSize` is bytes.
        
        if let d = image.jpegData(compressionQuality: initialHigh), d.count <= maxSize {
            return (d, initialHigh)
        }

        guard var hiData = image.jpegData(compressionQuality: initialHigh) else { return nil }
        guard var loData = image.jpegData(compressionQuality: initialLow)  else { return nil }

        var hiQ = initialHigh, hiB = hiData.count
        var loQ = initialLow,  loB = loData.count

        if loB > hiB {
            swap(&loQ, &hiQ)
            swap(&loData, &hiData)
            swap(&loB, &hiB)
        }

        if abs(CGFloat(hiB - maxSize)) <= CGFloat(maxSize) * toleranceRatio {
            return (hiData, hiQ)
        }
        if abs(CGFloat(loB - maxSize)) <= CGFloat(maxSize) * toleranceRatio {
            return (loData, loQ)
        }
        var cache: [CGFloat: Int] = [hiQ: hiB, loQ: loB]

        var low = minQuality
        var high = initialHigh

        for _ in 0..<maxIters {
            let denom = CGFloat(hiB - loB)
            var qNext: CGFloat

            if denom != 0 {
                qNext = loQ + (CGFloat(maxSize - loB)) * (hiQ - loQ) / denom
            } else {
                qNext = (low + high) / 2
            }

            qNext = max(min(qNext, high), low)
            if qNext == low { qNext = min(low + 0.05, high) }
            if qNext == high { qNext = max(high - 0.05, low) }

            if let _ = cache[qNext] {
                qNext = (low + high) / 2
            }

            guard let nextData = image.jpegData(compressionQuality: qNext) else { break }
            let bytes = nextData.count
            cache[qNext] = bytes

            if abs(CGFloat(bytes - maxSize)) <= CGFloat(maxSize) * toleranceRatio {
                return (nextData, qNext)
            }

            if bytes > maxSize {
                high = qNext
                hiQ = qNext; hiB = bytes; hiData = nextData
            } else {
                low = qNext
                loQ = qNext; loB = bytes; loData = nextData
            }
        }

        return loB <= maxSize ? (loData, loQ) : (hiData, hiQ)
    }
    
    public func fetchUserWithProfile(userId: UUID) async throws -> RapidUserWithProfile {
        let user = try await self.fetchUser(id: userId)
        let profileImages = try await self.fetchProfileImagesWithURLs(userId: userId)
        let userWithProfile = RapidUserWithProfile(user: user, profileImages: profileImages)
        
        return userWithProfile
    }

    public func fetchProfileImagesWithURLs(userId: UUID) async throws -> [UserProfileImage] {
        let uploadedImages = try await self.fetchProfileImages(userId: userId)
        let sortedImages = uploadedImages.sorted(by: { $0.imageIndex < $1.imageIndex })
        
        let paths = sortedImages.map { $0.storagePath }
        let signedURLs = try await self.getSignedURLs(bucket: "profile", paths: paths)
        
        let profileImages = sortedImages.compactMap { uploadedImage -> UserProfileImage? in
            guard let url = signedURLs[uploadedImage.storagePath] else { return nil }
            
            let fileName = (uploadedImage.storagePath as NSString).lastPathComponent
            let uuidString = fileName.replacingOccurrences(of: ".jpg", with: "")
                                    .replacingOccurrences(of: ".jpeg", with: "")
                                    .replacingOccurrences(of: ".png", with: "")
            let uuid = UUID(uuidString: uuidString) ?? .init()
            
            return UserProfileImage(imageURL: url, id: uuid)
        }
        return profileImages
    }
}

// MARK: - Session
extension SupabaseManager {
    public func refreshSession() async throws -> Session {
        return try await self.client.auth.refreshSession()
    }
}

// MARK: - Recruitment
extension SupabaseManager {
    public func postRecruitment(
        recruitment: Recruitment,
        places: [RecruitmentPlace],
        placeTypes: [RecruitmentPlaceType],
        tags: [RecruitmentHashTag]
    ) async throws {
        try await self.client
            .from("recruitments")
            .insert(recruitment)
            .execute()
        
        try await self.client
            .from("recruitment_places")
            .insert(places)
            .execute()
        
        if !tags.isEmpty {
            try await self.client
                .from("recruitment_hash_tags")
                .insert(tags)
                .execute()
        }
        
        if !placeTypes.isEmpty {
            try await self.client
                .from("recruitment_place_types")
                .insert(placeTypes)
                .execute()
        }
    }
    
    public func insertSpotHistories(histories: [SpotHistory]) async throws {
        try await self.client
            .from("spot_histories")
            .insert(histories)
            .execute()
    }
    
    public func fetchLocationHistories(offset: Int, limit: Int = 20) async throws -> [SpotHistory] {
        guard let session = await self.getSession() else { return [] }
        let from = offset
        let to = offset + limit - 1
        let histories: [SpotHistory] = try await self.client
            .from("spot_histories")
            .select("*")
            .eq("user_id", value: session.user.id)
            .range(from: from, to: to)
            .execute()
            .value
        return histories
    }
    
    public func updateRecruitmentMessage(id: UUID, message: String) async throws {
        try await client
            .from("recruitments")
            .update(["message": message])
            .eq("recruitment_id", value: id)
            .execute()
    }
    
    public func closeRecruitment(id: UUID) async throws {
        try await client
            .from("recruitments")
            .update(["status": "closed"])
            .eq("recruitment_id", value: id)
            .execute()
    }
    
    public func selectRecruitment(recruitmentId: UUID) async -> [RecruitmentWithRelations]? {
        let query = """
            *,
            recruitment_hash_tags(*),
            recruitment_places(*),
            recruitment_place_types(*)
            """
        
        do {
            let response: [RecruitmentWithRelations] = try await self
                .client
                .from("recruitments")
                .select(query)
                .eq("recruitment_id", value: recruitmentId)
                .execute()
                .value
            
            return response
        } catch let error {
            logger.error("❌ Failed to select recruitment: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    public func selectRecruitments(recruitmentIds: [UUID], limit: Int = 20, offset: Int = 0) async -> [RecruitmentWithRelations]? {
        let query = """
            *,
            recruitment_hash_tags(*),
            recruitment_places(*),
            recruitment_place_types(*)
            """
        let from = offset
        let to = offset + limit - 1
        do {
            let response: [RecruitmentWithRelations] = try await self
                .client
                .from("recruitments")
                .select(query)
                .in("recruitment_id", values: recruitmentIds)
                .order("post_date", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
            
            return response
        } catch let error {
            logger.error("❌ Failed to select recruitments: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    public func selectChatRooms(userId: UUID, offset: Int = 0, limit: Int = 20) async throws -> [ChatRoom] {
        let from = offset
        let to = offset + limit - 1
        
        let matchPairs: [MatchPair] = try await self.client
            .from("match_pairs")
            .select("*")
            .eq("user_id", value: userId)
            .range(from: from, to: to)
            .execute()
            .value
        
        let roomIds = matchPairs.map({ $0.roomId })
        let rooms: [ChatRoom] = try await self.client
            .from("chat_rooms")
            .select("*")
            .in("room_id", values: roomIds)
            .execute()
            .value
        
        return rooms
    }
    
    public func selectChatRoom(roomId: UUID) async throws -> ChatRoom? {
        let chatRooms: [ChatRoom] = try await self.client
            .from("chat_rooms")
            .select("*")
            .eq("room_id", value: roomId)
            .execute()
            .value
        
        return chatRooms.first
    }
    
    public func selectRoomUser(roomId: UUID, userId: UUID) async throws -> UUID? {
        let matchPairs: [MatchPair] = try await self.client
            .from("match_pairs")
            .select("*")
            .eq("room_id", value: roomId)
            .not("user_id", operator: .eq, value: userId)
            .execute()
            .value
        
        if let matchPair = matchPairs.first {
            return matchPair.userId
        }
        
        return nil
    }
    
    public func fetchMatchedUserIds() async throws -> [UUID] {
        guard let session = await self.getSession() else { return [] }
        let matchPairs: [MatchPair] = try await self.client
            .from("match_pairs")
            .select("*")
            .eq("user_id", value: session.user.id)
            .execute()
            .value
        
        return matchPairs.map({ $0.matchUserId })
    }
    
    public func selectChatMessages(roomId: UUID, offset: Int = 0, limit: Int = 100) async throws -> [ChatMessage] {
        let from = offset
        let to = offset + limit - 1
        let chatMessages: [ChatMessage] = try await self.client
            .from("chat_messages")
            .select("*")
            .eq("room_id", value: roomId)
            .order("created_at", ascending: false)
            .limit(limit)
            .range(from: from, to: to)
            .execute()
            .value
        
        return chatMessages.sorted(by: { $0.createdAt < $1.createdAt })
    }
    
    public func selectChatRoomLog(roomId: UUID, userId: UUID) async throws -> [ChatRoomLog] {
        let chatRoomLogs: [ChatRoomLog] = try await self.client
            .from("chat_room_logs")
            .select("*")
            .eq("room_id", value: roomId)
            .eq("user_id", value: userId)
            .order("enter_date", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return chatRoomLogs
    }
    
    public func insertChatRoomLog(roomId: UUID) async throws {
        guard let session = await self.getSession() else { return }
        let chatRoomLog = ChatRoomLog(id: .init(), userId: session.user.id, roomId: roomId, enterDate: .now)
        try await self.client
            .from("chat_room_logs")
            .insert(chatRoomLog)
            .execute()
    }
    
    public func checkChatRoomMessages(roomId: UUID) async throws {
        guard let session = await self.getSession() else { return }
        
        struct UpdateColumn: Codable {
            var checked: Bool
            var checkedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case checked
                case checkedAt = "checked_at"
            }
        }
        
        let updateColumns = UpdateColumn(checked: true, checkedAt: .now)
        try await self.client
            .from("chat_messages")
            .update(updateColumns)
            .eq("to_user_id", value: session.user.id)
            .execute()
    }
    
    public func upsertChatRoomMesageNotification(roomId: UUID, isOn: Bool) async throws {
        guard let session = await self.getSession() else { return }
        let body = ChatMessageNotification(id: .init(), userId: session.user.id, roomId: roomId, isOn: isOn, updatedAt: .now)
        try await self.client
            .from("chat_notification_messages")
            .upsert(body)
            .execute()
    }
}

// MARK: - Voice Chat Room
extension SupabaseManager {
    public func checkSubscribed() async throws -> Bool {
        guard let session = await self.getSession() else { return false }
        let currentUser: RapidUser = try await self.client
            .from("users")
            .select("*")
            .eq("user_id", value: session.user.id)
            .single()
            .execute()
            .value
        
        if currentUser.subscriptionStatus == "normal" {
            return false
        }
        
        return true
    }
    
    public func checkMadeRecruitment() async throws -> Recruitment? {
        guard let session = await self.getSession() else { return nil }
        let recruitments: [Recruitment] = try await self.client
            .from("recruitments")
            .select("*")
            .eq("user_id", value: session.user.id)
            .eq("status", value: "active")
            .order("post_date", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return recruitments.first
    }
    
    public func checkIsIdentityVerified() async throws -> Bool {
        guard let session = await self.getSession() else { return false }
        let currentUser: RapidUser = try await self.client
            .from("users")
            .select("*")
            .eq("user_id", value: session.user.id)
            .single()
            .execute()
            .value
        
        if let isIdentityVerified = currentUser.isIdentityVerified {
            return isIdentityVerified
        }
        
        return false
    }

    public func fetchMyRecruitments(offset: Int, limit: Int = 20) async throws -> [RecruitmentWithRelations] {
        guard let session = await self.getSession() else { return [] }
        let query = """
            *,
            recruitment_hash_tags(*),
            recruitment_places(*),
            recruitment_place_types(*)
            """
        let from = offset
        let to = offset + limit - 1
        
        let response: [RecruitmentWithRelations] = try await self.client
            .from("recruitments")
            .select(query)
            .eq("user_id", value: session.user.id)
            .order("post_date", ascending: false)
            .range(from: from, to: to)
            .execute()
            .value
        
        return response
    }
    
    public func checkLikedVoiceChatRoom(roomId: UUID) async throws -> Bool {
        guard let session = await self.getSession() else { return false }
        let likeVoiceChatRooms: [LikeVoiceChatRoom] = try await self.client
            .from("voice_chat_room_like_users")
            .select("*")
            .eq("room_id", value: roomId)
            .eq("user_id", value: session.user.id)
            .execute()
            .value
        
        return likeVoiceChatRooms.count == 1
    }
    
    public func selectLikedUserToVoiceChatRoom(limit: Int = 99) async throws -> [LikeVoiceChatRoom] {
        guard let session = await self.getSession() else { return [] }
        let voiceChatRooms: [VoiceChatRoom] = try await self.client
            .from("voice_chat_rooms")
            .select("*")
            .eq("user_id", value: session.user.id)
            .execute()
            .value
        
        if let voiceChatRoom = voiceChatRooms.first {
            let likedUsers: [LikeVoiceChatRoom] = try await self.client
                .from("voice_chat_room_like_users")
                .select("*")
                .eq("room_id", value: voiceChatRoom.id)
                .limit(limit)
                .execute()
                .value
            
            return likedUsers
        }
        
        return []
    }
    
    public func selectVoiceChatRoom(userId: UUID) async throws -> VoiceChatRoom? {
        let voiceChatRooms: [VoiceChatRoom] = try await self.client
            .from("voice_chat_rooms")
            .select("*")
            .eq("user_a_id", value: userId)
            .execute()
            .value
        
        return voiceChatRooms.first
    }
    
    public func selectLatestVoiceChatEvent() async throws -> VoiceChatEvent? {
        let events: [VoiceChatEvent] = try await self.client
            .from("voice_chat_events")
            .select("*")
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return events.first
    }
    
    public func upsertVoiceChatEventJoinedUser(body: VoiceChatEventJoinedUser) async throws {
        try await self.client
            .from("voice_chat_event_joined_users")
            .upsert(body)
            .execute()
    }
    
    public func fetchVoiceChatEventJoinedUser(eventId: UUID) async throws -> VoiceChatEventJoinedUser? {
        guard let session = await self.getSession() else { return nil }
        let joinedUsers: [VoiceChatEventJoinedUser] = try await self.client
            .from("voice_chat_event_joined_users")
            .select("*")
            .eq("user_id", value: session.user.id)
            .eq("event_id", value: eventId)
            .execute()
            .value
        
        return joinedUsers.first
    }
    
    public func fetchVoiceChatEventPairs(eventId: UUID) async throws -> [VoiceChatEventPair] {
        guard let session = await self.getSession() else { return [] }
        let pairs: [VoiceChatEventPair] = try await self.client
            .from("voice_chat_event_pairs")
            .select("*")
            .eq("from_user_id", value: session.user.id)
            .eq("event_id", value: eventId)
            .execute()
            .value
        
        return pairs
    }
    
    // MARK: - Notification message
    public func fetchNotificationMessages(offset: Int, limit: Int = 27) async throws -> [NotificationMessage] {
        guard let session = await self.getSession() else { return [] }
        let from = offset
        let to = offset + limit - 1
        
        let messages: [NotificationMessage] = try await self.client
            .from("notification_messages")
            .select("*")
            .eq("user_id", value: session.user.id)
            .range(from: from, to: to)
            .execute()
            .value
        return messages
    }
    
    public func updateNotificationMessages(messages: [NotificationMessage]) async throws {
        // Collect IDs of messages that are marked as read
        let readIds = messages.filter { $0.isRead }.map { $0.id }
        
        guard !readIds.isEmpty else { return }
        
        // Update only the 'is_read' column for matching IDs
        try await self.client
            .from("notification_messages")
            .update(["is_read": true])
            .in("message_id", values: readIds)
            .execute()
    }
    
    public func updateTotalPointToUsersTable(totalPoint: Int) async throws {
        guard let session = await self.getSession() else { return }
        try await self.client
            .from("users")
            .update(["total_point": totalPoint])
            .eq("user_id", value: session.user.id)
            .execute()
    }
    
    public func deleteProfileImages(deleteImage: [UserProfileImage]) async throws {
        guard let userId = await getSession()?.user.id.uuidString.lowercased() else { return }
        
        // Construct the paths as they are stored in the database and storage
        // Format: users/userId/imageId.jpg
        let storagePaths = deleteImage.map { "users/\(userId)/\($0.id.uuidString.lowercased()).jpg" }
        let imageIds = deleteImage.map({ $0.id })
        
        // 1. Delete from database table 'profile_images'
        try await self.client
            .from("profile_images")
            .delete()
            .in("id", values: imageIds)
            .execute()
        
        // 2. Delete from storage bucket 'profile'
        try await self.client.storage
            .from("profile")
            .remove(paths: storagePaths)
    }
    
    public func fetchProfileImages(userId: UUID) async throws -> [ProfileUploadedImage] {
        let uploadedImages: [ProfileUploadedImage] = try await self.client
            .from("profile_images")
            .select("*")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return uploadedImages
    }
}
