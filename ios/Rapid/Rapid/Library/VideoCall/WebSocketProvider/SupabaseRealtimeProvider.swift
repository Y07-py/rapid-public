//
//  SupabaseRealtimeProvider.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/14.
//

import Foundation
import Supabase

public class SupabaseRealtimeProvider: WebSocketProvider {    
    var delegate: WebSocketProviderDelegate?
    public var callId: String?
    
    private let client: SupabaseClient
    private let logger = Logger.shared
    
    public var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var greetListenTask: Task<Void, Never>?
    
    init(callId: String) {
        let supabaseKey: String = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as! String
        let urlString: String = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_BASE_URL") as! String
        
        self.client = SupabaseClient(
            supabaseURL: URL(string: urlString)!,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true)
            ))
        self.callId = callId
    }
    
    public func connect() {
        guard channel == nil, let callId = callId else { return }
        
        let channel = client.channel("webrtc:\(callId)")
        self.channel = channel
        
        // Get realtime broadcast
        let broadcastStream = channel.broadcastStream(event: "signal")
        let greetBroadcastStream = channel.broadcastStream(event: "greet")
        
        
        // Start subscribe
        Task {
            do {
                try await channel.subscribeWithError()
                await MainActor.run {
                    self.delegate?.webSocketDidConnect(self)
                }
            } catch let error {
                await MainActor.run {
                    self.delegate?.webSocketDidError(self, didError: error)
                    self.delegate?.webSocketDidDisconnect(self)
                }
                return
            }
        }
        
        self.listenTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await jsonObject in broadcastStream {
                do {
                    let payload = try jsonObject["payload"]?.decode(as: SignalMessage.self)
                    let data = try JSONEncoder().encode(payload)
                    await MainActor.run {
                        self.delegate?.webSocket(self, didReceiveData: data)
                    }
                } catch let error {
                    await MainActor.run {
                        self.delegate?.webSocketDidError(self, didError: error)
                    }
                }
            }
        }
        
        self.greetListenTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await jsonObject in greetBroadcastStream {
                do {
                    guard let payload = try jsonObject["payload"]?.decode(as: GreetMessage.self) else { return }
                    
                    await MainActor.run {
                        NotificationCenter.default.post(name: .receiveVideoSignalNotification, object: nil, userInfo: ["greet": payload])
                    }
                } catch let error {
                    await MainActor.run {
                        self.delegate?.webSocketDidError(self, didError: error)
                    }
                }
            }
        }
    }
    
    public func send(data: Data) {
        guard let channel = self.channel else {
            logger.error("❌ Tried to send but it haven't channel.")
            return
        }

        Task {
            do {
                let message = try JSONDecoder().decode(SignalMessage.self, from: data)
                if await channel.status == .subscribed {
                    try await channel.broadcast(event: "signal", message: message)
                } else {
                    try await channel.httpSend(event: "signal", message: message)
                }
            } catch let error {
                self.delegate?.webSocketDidError(self, didError: error)
            }
        }
    }
    
    public func close() {
        guard let channel = self.channel else {
            logger.error("❌ Tried to close, but it haven't channel.")
            return
        }
        
        guard let senderId = client.auth.currentUser?.id.uuidString else {
            logger.error("❌ Failed to get current user uid.")
            return
        }
        
        guard let callId = self.callId else {
            logger.error("❌ Failed to get call id.")
            return
        }
        
        Task {
            do {
                let byeMessage = GreetMessage(callId: callId, senderId: senderId, type: .bye)
                if await channel.status == .subscribed {
                    try await channel.broadcast(event: "greet", message: byeMessage)
                } else {
                    try await channel.httpSend(event: "greet", message: byeMessage)
                }
            } catch let error {
                self.delegate?.webSocketDidError(self, didError: error)
            }
        }
    }
    
    public func start() {
        guard let channel = self.channel else {
            logger.error("❌ Tried to start, but it haven't channel.")
            return
        }
        
        guard let senderId = self.client.auth.currentUser?.id.uuidString else {
            logger.error("❌ Failed to get current user uid.")
            return
        }
        
        guard let callId = self.callId else {
            logger.error("❌ Failed to get call id.")
            return
        }
        
        Task {
            do  {
                let hiMessage = GreetMessage(callId: callId, senderId: senderId, type: .hi)
                if await channel.status == .subscribed {
                    try await channel.broadcast(event: "greet", message: hiMessage)
                } else {
                    try await channel.httpSend(event: "greet", message: hiMessage)
                }
            } catch let error {
                self.delegate?.webSocketDidError(self, didError: error)
            }
        }
    }
}
