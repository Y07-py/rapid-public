//
//  NotificationViewModel.swift
//  Rapid
//
//  Created by Antigravity on 2026/02/23.
//

import Foundation
import UserNotifications
import SwiftUI
import Combine

public struct BannerContent: Identifiable {
    public let id = UUID()
    let title: String
    let body: String
    let iconName: String
    let systemIcon: Bool
    let color: Color
    let imageURL: URL?
    let bannerType: String
    let customData: [String: String]
}

public class NotificationViewModel: ObservableObject {
    @Published public var isPushMatching: Bool = true
    @Published public var isPushMessage: Bool = true
    @Published public var isPushFootprint: Bool = true
    @Published public var isEmailNews: Bool = true
    
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    // Banner management
    @Published public var showBanner: Bool = false
    @Published public var bannerContent: BannerContent? = nil
    
    private let logger = Logger.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        Task { @MainActor in
            checkAuthorizationStatus()
        }
        loadSettings()
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Matching
        NotificationCenter.default.publisher(for: .matchingNotification)
            .sink { [weak self] notification in
                let userId = notification.userInfo?["user_id"] as? String
                self?.showNotificationBanner(
                    title: "マッチング成立！",
                    body: "新しいマッチングがあります。確認してみましょう。",
                    systemIcon: "heart.fill",
                    color: .mainColor,
                    userId: userId,
                    bannerType: "matching"
                )
            }
            .store(in: &cancellables)
        
        // Message
        NotificationCenter.default.publisher(for: .receiveMessageNotification)
            .sink { [weak self] notification in
                guard let userId = notification.userInfo?["user_id"] as? String,
                      let roomId = notification.userInfo?["room_id"] as? String else { return }
                
                self?.showNotificationBanner(
                    title: "メッセージ受信",
                    body: "新しいメッセージが届きました。",
                    systemIcon: "message.fill",
                    color: .blue,
                    userId: userId,
                    bannerType: "message",
                    customData: ["roomId": roomId, "userId": userId]
                )
            }
            .store(in: &cancellables)
        
        // Like (Recruitment/Location)
        NotificationCenter.default.publisher(for: .likedNotification)
            .sink { [weak self] notification in
                let userId = notification.userInfo?["user_id"] as? String
                self?.showNotificationBanner(
                    title: "いいね！",
                    body: "あなたの投稿にいいねが届きました。",
                    systemIcon: "hand.thumbsup.fill",
                    color: .mainColor,
                    userId: userId,
                    bannerType: "like"
                )
            }
            .store(in: &cancellables)
        
        // Introduction moderate result
        NotificationCenter.default.publisher(for: .receiveIntroductionModerateNotification)
            .sink { [weak self] notification in
                let userId = notification.userInfo?["user_id"] as? String
                self?.showNotificationBanner(
                    title: "自己紹介文の審査結果",
                    body: "自己紹介文の審査が完了しました。詳細を確認しましょう。",
                    systemIcon: "person.text.rectangle.fill",
                    color: .green,
                    userId: userId,
                    bannerType: "introduction_moderate"
                )
            }
            .store(in: &cancellables)
        
        // Profile image review result
        NotificationCenter.default.publisher(for: .receiveProfileImageReviewNotification)
            .sink { [weak self] notification in
                let userId = notification.userInfo?["user_id"] as? String
                self?.showNotificationBanner(
                    title: "プロフィールの審査結果",
                    body: "プロフィールの審査が完了しました。詳細を確認しましょう。",
                    systemIcon: "photo.badge.checkmark",
                    color: .blue,
                    userId: userId,
                    bannerType: "profile_image_review"
                )
            }
            .store(in: &cancellables)
    }
    
    private func showNotificationBanner(
        title: String,
        body: String,
        systemIcon: String,
        color: Color,
        userId: String? = nil,
        bannerType: String,
        customData: [String: String] = [:]
    ) {
        Task { @MainActor in
            var imageURL: URL? = nil
            
            if let userId = userId {
                do {
                    let profileURLs = try await SupabaseManager.shared.getPresignURLFromStorage(
                        bucket: "profile",
                        folder: "users/\(userId.lowercased())"
                    )
                    imageURL = profileURLs.values.first
                } catch {
                    self.logger.error("❌ Failed to fetch user profile image for banner: \(error.localizedDescription)")
                }
            }
            
            self.bannerContent = BannerContent(
                title: title,
                body: body,
                iconName: systemIcon,
                systemIcon: true,
                color: color,
                imageURL: imageURL,
                bannerType: bannerType,
                customData: customData
            )
            self.showBanner = true
        }
    }
    
    /// Request notification authorization from the user
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                self.logger.error("❌ Failed to request notification authorization: \(error.localizedDescription)")
            }
            
            Task { @MainActor in
                self.checkAuthorizationStatus()
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    /// Check the current notification authorization status
    public func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    /// Load settings from local storage (initial implementation)
    private func loadSettings() {
        // TODO: Load from Supabase in the future
        self.isPushMatching = UserDefaults.standard.bool(forKey: "isPushMatching") 
        self.isPushMessage = UserDefaults.standard.bool(forKey: "isPushMessage")
        self.isPushFootprint = UserDefaults.standard.bool(forKey: "isPushFootprint")
        self.isEmailNews = UserDefaults.standard.bool(forKey: "isEmailNews")
        
        // Handle first launch case (UserDefaults returns false by default)
        if UserDefaults.standard.object(forKey: "isPushMatching") == nil {
            self.isPushMatching = true
            self.isPushMessage = true
            self.isPushFootprint = true
            self.isEmailNews = true
        }
    }
    
    /// Save settings locally and eventually to the server
    @MainActor
    public func updateSettings() {
        UserDefaults.standard.set(isPushMatching, forKey: "isPushMatching")
        UserDefaults.standard.set(isPushMessage, forKey: "isPushMessage")
        UserDefaults.standard.set(isPushFootprint, forKey: "isPushFootprint")
        UserDefaults.standard.set(isEmailNews, forKey: "isEmailNews")
        
        Task {
            await syncSettingsWithServer()
        }
    }
    
    /// Sync settings with Supabase
    private func syncSettingsWithServer() async {
        // TODO: Implement Supabase sync logic
        // try await SupabaseManager.shared.updateNotificationSettings(...)
    }
}
