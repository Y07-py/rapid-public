//
//  WebSocketProvider.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/14.
//

import Foundation
import Supabase

protocol WebSocketProvider: AnyObject {
    var callId: String? { get set }
    var delegate: WebSocketProviderDelegate? { get set }
    func connect()
    func send(data: Data)
    func close()
    func start()
}

protocol WebSocketProviderDelegate: AnyObject {
    func webSocketDidConnect(_ webSocket: WebSocketProvider)
    func webSocketDidDisconnect(_ webSocket: WebSocketProvider)
    func webSocket(_ webSocket: WebSocketProvider, didReceiveData data: Data)
    func webSocketDidError(_ webSocket: WebSocketProvider, didError error: Error)
}
