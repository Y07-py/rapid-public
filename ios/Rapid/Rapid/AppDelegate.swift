//
//  AppDelegate.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/07.
//

import Foundation
import UIKit
import GoogleSignIn
import GoogleMaps
import GooglePlaces
import UserNotifications
import WebRTC
import FirebaseCore
import FirebaseMessaging
import PushKit
import CallKit
import Combine


class AppDelegate: UIResponder {
    private let http: HttpClient = {
        let client = HttpClient(retryPolicy: .exponentialBackoff(3, 4.5))
        return client
    }()
    
    private let callProvider = CXProvider(configuration: CXProviderConfiguration())
    private var callPayloads: [String: CallPayload] = [:]
}

extension AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        
        guard let googleAPIKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_SERVICE_API_KEY") as? String else { return false }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge,]) { (granted, error) in
            if let error = error {
                Logger.shared.error("❌ Failed to request notification: \(error.localizedDescription)")
            }
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        
        // Request for notification
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        
        // Setting myself as the recipient for FCM tokens.
        Messaging.messaging().delegate = self
        
        SupabaseManager.shared.initialize()
        GMSServices.provideAPIKey(googleAPIKey)
        GMSPlacesClient.provideAPIKey(googleAPIKey)
        
        // Setting VoIP token
        let voipRegistory = PKPushRegistry(queue: .main)
        voipRegistory.desiredPushTypes = [.voIP]
        voipRegistory.delegate = self
        
        // Setting call provider
        callProvider.setDelegate(self, queue: nil)
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        
        Task {
            guard let session = await SupabaseManager.shared.getSession() else { return }
            let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
            let deviceToken = DeviceToken(uid: session.user.id.uuidString, token: tokenString, createdAt: .now)
            CoreDataStack.shared.save(deviceToken)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// When the applicatiion foreground, do not display notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Banner is not presented when running app.
        completionHandler([])

        let userInfo = notification.request.content.userInfo
        if let type = (userInfo["notification_type"] as? String) ?? (userInfo["message_type"] as? String) {
            if type == "message" {
                guard let roomId = userInfo["room_id"] as? String,
                      let userId = userInfo["user_id"] as? String else { return }
                print(roomId)
                NotificationCenter.default.post(
                    name: .receiveMessageNotification,
                    object: nil,
                    userInfo: ["room_id": roomId, "user_id": userId]
                )
            } else if type == "matching" {
                guard let roomId = userInfo["room_id"] as? String,
                      let userId = userInfo["user_id"] as? String else { return }
                NotificationCenter.default.post(
                    name: .matchingNotification,
                    object: nil,
                    userInfo: ["room_id": roomId, "user_id": userId]
                )
            } else if type == "like" {
                guard let userId = userInfo["user_id"] as? String else { return }
                let recruitmentId = userInfo["recruitment_id"] as? String
                NotificationCenter.default.post(
                    name: .likedNotification,
                    object: nil,
                    userInfo: ["user_id": userId, "recruitment_id": recruitmentId].compactMapValues { $0 }
                )
            } else if type == "review_result" || type == "profile_image_approved" || type == "profile_image_rejected" {
                guard let imageId = userInfo["image_id"] as? String,
                      let userId = userInfo["user_id"] as? String else { return }
                NotificationCenter.default.post(
                    name: .receiveProfileImageReviewNotification,
                    object: nil,
                    userInfo: ["user_id": userId, "image_id": imageId]
                )
            } else if type.hasPrefix("introduction") {
                guard let userId = userInfo["user_id"] as? String else { return }
                NotificationCenter.default.post(name: .receiveIntroductionModerateNotification, object: nil, userInfo: ["user_id": userId])
            } else if type.hasPrefix("identity_verification") {
                guard let userId = userInfo["user_id"] as? String else { return }
                NotificationCenter.default.post(name: .receiveIdentityVerificationNotification, object: nil, userInfo: ["user_id": userId])
            } else if type == "maintenance" {
                let isMaintenance = userInfo["is_maintenance"] as? String == "true"
                NotificationCenter.default.post(
                    name: .receiveMaintenanceNotification,
                    object: nil,
                    userInfo: ["is_maintenance": isMaintenance]
                )
            } else if type == "voice_chat_started" {
                NotificationCenter.default.post(name: .receiveVoiceChatStartedNotification, object: nil)
            } else if type == "voice_chat_matched" {
                guard let callId = userInfo["call_id"] as? String,
                      let role = userInfo["role"] as? String,
                      let opponentUserId = userInfo["opponent_user_id"] as? String,
                      let opponentName = userInfo["opponent_name"] as? String else { return }
                print("matched")
                NotificationCenter.default.post(
                    name: .receiveVoiceChatMatchedNotification,
                    object: nil,
                    userInfo: [
                        "call_id": callId,
                        "role": role,
                        "opponent_user_id": opponentUserId,
                        "opponent_name": opponentName
                    ]
                )
            }
        }
    }
}

extension AppDelegate: MessagingDelegate {
    /// Process for storing the FCM token obtained from Firebaes on the server.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let fcmToken = fcmToken {
            UserDefaults.standard.set(fcmToken, forKey: "last_fcm_token")
            SupabaseManager.shared.registFCMPayload()
        }
    }
}

// MARK: - VoIP handling
extension AppDelegate: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let deviceToken = pushCredentials.token.map({ String(format: "%02x", $0) }).joined()
        /// Send device token to out backend server.
        Task {
            // Wait for real internet reachability
            while !NetworkMonitor.shared.isRealInternetReachable {
                try? await Task.sleep(nanoseconds: 1 * 1_000_000_000) // retry check every 1s
            }
            
            guard let session = await SupabaseManager.shared.getSession() else { return }
            let device = VoIPDeviceToken(userId: session.user.id, deviceToken: deviceToken)
            
            do {
                let response = try await self.http
                    .setAuth(httpAuth: HttpSupabaseAuthenticator())
                    .post(url: .registVoIPDeviceToken, content: device)
                if response.ok {
                    print("✅ Successfully to regist VoIP device token.")
                }
            } catch let error {
                if let error = error as? HttpError {
                    print("❌ Failed to send device token: \(error.errorDescription)")
                }
            }
        }
    }
    
    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        let dictionary = payload.dictionaryPayload
        if let data = try? JSONSerialization.data(withJSONObject: dictionary, options: []) {
            guard let callPayload = try? JSONDecoder().decode(CallPayload.self, from: data),
                  let callUUID = UUID(uuidString: callPayload.callId) else {
                completion()
                return
            }
                    
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: callPayload.handle)
            update.localizedCallerName = callPayload.callerName
            
            self.callPayloads[callPayload.callId] = callPayload
            callProvider.reportNewIncomingCall(with: callUUID, update: update) { error in
                if let error = error {
                    print("❌ Failed to call report. \(error.localizedDescription)")
                    return
                }
                completion()
            }
        } else {
            completion()
        }
    }
}

// MARK: - Call handling
extension AppDelegate: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        NotificationCenter.default.post(name: .performEndCallNotification, object: nil)
        AudioSessionManager.shared.deactivate()
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let callId = action.callUUID.uuidString.lowercased()
        var userInfo: [AnyHashable: Any] = ["callUUID": action.callUUID]
        if let payload = self.callPayloads[callId] {
            userInfo["callerName"] = payload.callerName
            userInfo["handle"] = payload.handle
        }
        NotificationCenter.default.post(name: .performAnswerCallNotification, object: nil, userInfo: userInfo)
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        NotificationCenter.default.post(name: .performEndCallNotification, object: nil, userInfo: ["callUUID": action.callUUID])
        
        AudioSessionManager.shared.deactivate()
        
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    }
}
