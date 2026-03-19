//
//  ContentViewModel.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/10.
//

import Foundation
import SwiftUI
import FirebaseMessaging
import Combine

enum LoginStatus {
    case unknown
    case loggedIn
    case loggedOut
}

@MainActor
class ContentViewModel: ObservableObject {
    @Published var loginStatus: LoginStatus = .unknown
    @Published var isMaintenanceMode: Bool = false
    
    private let supabase = SupabaseManager.shared
    private let http: HttpClient = {
        let client = HttpClient(retryPolicy: .exponentialBackoff(3, 4.5))
        return client
    }()
    
    private var cancellables = Set<AnyCancellable>()
    private var isDataLoaded = false
    
    init() {
        // Monitor network connection and check session when established
        NetworkMonitor.shared.$isRealInternetReachable
            .filter { $0 && !self.isDataLoaded }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.startNetworkInitialization()
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .receiveMaintenanceNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let isMaint = notification.userInfo?["is_maintenance"] as? Bool ?? true
                self?.isMaintenanceMode = isMaint
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .retryMaintenanceCheckNotification)
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
        do {
            let response = try await http.get(url: .checkMaintenance)
            if response.ok {
                struct MaintenanceStatusResponse: Codable {
                    let is_maintenance: Bool
                }
                let status: MaintenanceStatusResponse = try response.decode()
                if status.is_maintenance {
                    self.isMaintenanceMode = true
                    self.isDataLoaded = true
                    return
                } else {
                    self.isMaintenanceMode = false
                }
            }
        } catch {
            print("Failed to check maintenance mode: \(error)")
        }
        
        // Waiting 3 seconds
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if await supabase.checkSession() {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                loginStatus = .loggedIn
            }
        } else {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                loginStatus = .loggedOut
            }
        }
        self.isDataLoaded = true
    }
}
