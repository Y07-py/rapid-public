//
//  LoginViewModel.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/09.
//

import Foundation
import SwiftUI
import PhoneNumberKit
import GoogleSignIn
import Auth0
import AuthenticationServices
import LineSDK
import CryptoKit

enum LoginType {
    case email
    case phoneNumber
    case line
    case google
    case apple
}

@MainActor
class LoginViewModel: NSObject, ObservableObject {
    @Published var selectedLoginType: LoginType = .email
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var countries: [Country] = []
    @Published var selectedCountry: Country = .init(flag: "🇯🇵", region: "JP", code: 81)
    @Published var otp: [OTPField: Character] = [:]
    @Published var waitMode: Bool = false
    
    private let logger = Logger.shared
    private let phoneNumberUtility = PhoneNumberUtility()
    private let supabase = SupabaseManager.shared
    private let coreData = CoreDataStack.shared
    private var auth0: WebAuth? = nil
    private var nonce: String = ""
    
    override init() {
        super.init()
        initializeCountries()
        configurationGoogleSignIn()
        initializeAuth0Authentication()
    }
    
    func formatForCountry(_ phonNumber: String) {
        do {
            let parsedNumber = try phoneNumberUtility.parse(phoneNumber, withRegion: selectedCountry.region)
            let formatted = phoneNumberUtility.format(parsedNumber, toType: .national)
            self.phoneNumber = formatted
        } catch let error {
            logger.error("Failed to format phone number: \(error.localizedDescription)")
        }
    }
    
    func signIn() async {
        self.waitMode = true
        defer { self.waitMode = false }
        do {
            switch selectedLoginType {
            case .email:
                try await self.supabase.signInOtpWithEmail(email)
            case .phoneNumber:
                try await self.supabase.signInOtpwithPhoneNumber(phoneNumber, country: selectedCountry)
            case .line:
                await signInWithLINE()
            case .google:
                await signInWithGoogle()
            case .apple:
                signInWithApple()
            }
        } catch let error {
            logger.error("❌ Failed to sign in: \(error.localizedDescription)")
            if let authError = error as? AuthError {
                NotificationCenter.default.post(
                    name: .loginErrorNotification,
                    object: nil,
                    userInfo: ["message": authError.errorDescription ?? ""]
                )
            }
        }
    }
    
    private func signInWithGoogle() async {
        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let vController = window.rootViewController else { return }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: vController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                return
            }
            let accessToken = result.user.accessToken.tokenString
            let email = result.user.profile?.email ?? ""
            
            // Check if email already exists in our system
            let isExistingUser = await self.supabase.checkEmailExist(email)
            self.logger.info("ℹ️ Login with Google: email \(email) exists: \(isExistingUser)")
            
            try await self.supabase.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            self.logger.info("✅ Successfully sign in with Google.")
            
            // Re-check session and ensure user record exists
            let status = await self.supabase.checkExistingSessionStatus()
            
            handleSessionStatus(status)
            
        } catch let error {
            logger.error("⚠️ Failed to sign in with Google: \(error.localizedDescription).")
        }
    }
    
    private func signInWithLINE() async {
        do {
            let credential = try await auth0?.connection("line")
                .scope("openid profile email")
                .start()
            
            if let credential = credential {
                try await self.supabase.signInWithAuth0(jwt: credential.idToken, accessToken: credential.accessToken)
                let status = await self.supabase.checkExistingSessionStatus()
                
                handleSessionStatus(status)
                self.logger.info("✅ Successfully authentication.")
            }
        } catch let error {
            logger.error("⚠️ Failed to sign in with LINE. :\(error.localizedDescription)")
        }
    }
    
    private func signInWithApple() {
        let nonce = randomNonceString()
        self.nonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func veryfyOtp() async {
        self.waitMode = true
        defer { self.waitMode = false }
        do {
            let otpToken = OTPField.allCases.compactMap { field in
                otp[field]
            }.map({ String($0) }).joined()
            
            if selectedLoginType == .email {
                try await supabase.verifyOtpWithEmail(email: email, otp: otpToken)
                logger.info("ℹ️ Successfully verify with OTP by email.")
            } else if selectedLoginType == .phoneNumber {
                try await supabase.verifyOtpWithPhoneNumber(phoneNumber: phoneNumber, otp: otpToken)
                logger.info("ℹ️ Successfully vetify with OTP by phone number.")
            }
            
            let status = await self.supabase.checkExistingSessionStatus()
            self.handleSessionStatus(status)
            
        } catch let error {
            if let httpError = error as? HttpError {
                logger.error("❌ Failed to verify with OTP: \(httpError.errorDescription)")
            } else {
                logger.error("❌ Failed to verify with OTP: \(error.localizedDescription)")
            }
        }
    }
    
    private func initializeCountries() {
        Locale.Region.isoRegions.forEach { region in
            let base: UInt32 = 127397
            var flag = ""
            for v in region.identifier.unicodeScalars {
                flag.unicodeScalars.append(UnicodeScalar(base + v.value)!)
            }
            guard region.identifier != "QO" && !region.identifier.contains(try! Regex("[0-9]+")) else { return }
            countries.append(.init(
                flag: String(flag),
                region: region.identifier,
                code: phoneNumberUtility.countryCode(for: region.identifier) ?? 0)
            )
        }
    }
    
    private func configurationGoogleSignIn() {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") else {
            logger.error("❌ GoogleService-Info.plist not found in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
            
            guard let clientID = plist?["CLIENT_ID"] as? String else {
                logger.error("❌ CLIENT_ID not found in GoogleService-Info.plist.")
                return
            }
            
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            logger.debug("✅ Google Sign-In configured successfully.")
            
        } catch {
            logger.error("❌ Failed to read GoogleService-Info.plist: \(error.localizedDescription).")
        }
    }
    
    private func initializeAuth0Authentication() {
        guard let url = Bundle.main.url(forResource: "Auth0", withExtension: "plist") else {
            logger.error("❌ Auth0.plist not found in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            guard let clientID = plist?["ClientId"] as? String,
                  let domain = plist?["Domain"] as? String else { return }
            
            self.auth0 = Auth0.webAuth(clientId: clientID, domain: domain)
        } catch {
            logger.error("❌ Failed to read Auth0.plist.: \(error.localizedDescription)")
            return
        }
    }

    private func handleSessionStatus(_ status: LoginSessionStatus) {
        switch status {
        case .completed:
            NotificationCenter.default.post(name: .pushRootViewNotification, object: nil, userInfo: ["root": MainRoot.home])
        case .profileIncomplete:
            NotificationCenter.default.post(name: .pushRootViewNotification, object: nil, userInfo: ["root": LoginRoot.setting])
        case .noSession:
            break
        }
    }
}

extension LoginViewModel: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor(frame: .zero)
        }
        return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            logger.error("⚠️ Failed to authorization with Apple.")
            return
        }
        
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            logger.error("⚠️ Failed to fetch idToken.")
            return
        }
        
        Task {
            self.waitMode = true
            do {
                try await self.supabase.signInWithApple(idToken: idToken, nonce: self.nonce)
                let status = await self.supabase.checkExistingSessionStatus()
                self.waitMode = false
                self.handleSessionStatus(status)
                logger.info("✅ Successfully signed in with Apple.")
            } catch {
                self.waitMode = false
                logger.error("⚠️ Faield to sign in with Apple: \(error.localizedDescription)")
            }
        }
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("❌ Unable to generate nonce. SecRandmCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hasheData = SHA256.hash(data: inputData)
        let hashString = hasheData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}


