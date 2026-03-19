//
//  Error.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/09/11.
//

import Foundation

public enum SupabaseError: Error {
    case notSignIn(String)
    
    var description: String {
        switch self {
        case .notSignIn(let message):
            return message
        }
    }
}
