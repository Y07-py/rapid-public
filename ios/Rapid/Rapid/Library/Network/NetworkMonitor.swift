//
//  NetworkMonitor.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/11.
//

import Foundation
import Network
import Combine

public class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    
    @Published public var isConnected: Bool = false
    @Published public var connectionType: ConnectionType = .unknown
    @Published public var isRealInternetReachable: Bool = false
    
    private let healthCheckURL = URL(string: .healthCheck)!
    private var reachabilityTimer: Timer?
    
    public enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let connected = path.status == .satisfied
                self?.isConnected = connected
                self?.getConnectionType(path)
                
                if connected {
                    self?.startReachabilityChecks()
                } else {
                    self?.isRealInternetReachable = false
                    self?.stopReachabilityChecks()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func startReachabilityChecks() {
        guard reachabilityTimer == nil else { return }
        
        // Initial check
        checkRealReachability()
        
        // Periodic check every 2 seconds until successful
        reachabilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkRealReachability()
        }
    }
    
    private func stopReachabilityChecks() {
        reachabilityTimer?.invalidate()
        reachabilityTimer = nil
    }
    
    private func checkRealReachability() {
        guard !isRealInternetReachable else {
            stopReachabilityChecks()
            return
        }
        
        var request = URLRequest(url: healthCheckURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, (httpResponse.statusCode == 200 || httpResponse.statusCode == 503) {
                    self?.isRealInternetReachable = true
                    self?.stopReachabilityChecks()
                } else {
                    self?.isRealInternetReachable = false
                }
            }
        }.resume()
    }
    
    private func getConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
    
    public func stopMonitoring() {
        monitor.cancel()
    }
}
