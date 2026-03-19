//
//  HttpAuth.swift
//  Http
//
//  Created by 木本瑛介 on 2025/12/31.
//

import Foundation
import Supabase

public protocol HttpAuth {
    func getToken() async throws -> String
    func setToken(token: String, expiresIn: TimeInterval) -> Void
    func refreshToken() async throws -> String
}


public class HttpSupabaseAuthenticator: HttpAuth {
    private let supabaseManager = SupabaseManager.shared
    private var token: String? = nil
    private var expiresAt: Date? = nil
    
    public init() {}
    
    public func getToken() async throws -> String {
        if let expiresAt = self.expiresAt, let token = self.token {
            
            // Check whether exceeded expires at.
            if Date.now >= expiresAt {
                return try await self.refreshToken()
            }
            
            return token
        }
        
        // If not exist session.
        return try await self.refreshToken()
    }
    
    public func setToken(token: String, expiresIn: TimeInterval) {
        self.token = token
        self.expiresAt = Date(timeIntervalSinceNow: expiresIn)
    }
    
    public func refreshToken() async throws -> String {
        let session = try await self.refreshSession()
        self.setToken(token: session.accessToken, expiresIn: session.expiresIn)
        return session.accessToken
    }
    
    private func refreshSession() async throws -> Session {
        return try await self.supabaseManager.refreshSession()
    }
}
