//
//  SupabaseType.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/03.
//

import Foundation
import Supabase

/// Importing supabaase in situations where `Task` usage is required causes the compiler to become confused
/// when identifying `Task` initializers, and the purpose is to avoid this.
public typealias SupabaseInsertAction = InsertAction
public typealias SupabaseRealtimeSubscription = RealtimeSubscription
