//
//  Subscription.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/04.
//

import Foundation
import SwiftUI
import Supabase

public struct SupabaseSubscription: Identifiable {
    /// Structure for holding the realtime subscription of the issued supabase in various classes.
    
    public var id: UUID
    public var channel: RealtimeChannelV2
    public var subscription: SupabaseRealtimeSubscription
    public var createdAt: Date
    
    public init(id: UUID?, channel: RealtimeChannelV2, subscription: SupabaseRealtimeSubscription, createdAt: Date = .now) {
        if let id = id {
            self.id = id
        } else {
            self.id = .init()
        }
        self.channel = channel
        self.subscription = subscription
        self.createdAt = createdAt
    }
}
