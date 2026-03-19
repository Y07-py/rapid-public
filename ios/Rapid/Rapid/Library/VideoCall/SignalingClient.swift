//
//  SignalingClient.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/14.
//

import Foundation
import WebRTC

protocol SignalingClientDelegate: AnyObject {
    func signalClientDidConnect(_ signalClient: SignalingClient)
    func signalClientDidDisconnect(_ signalClient: SignalingClient)
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription)
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate)
    func signalClientDidReceiveBye(_ signalClient: SignalingClient)
}

final public class SignalingClient {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    public let clientId: String
    private let webSocket: WebSocketProvider
    private let logger = Logger.shared
    weak var delegate: SignalingClientDelegate?
    
    init(clientId: String, webSocket: WebSocketProvider) {
        self.clientId = clientId
        self.webSocket = webSocket
    }
    
    public func connect() {
        guard let callId = self.webSocket.callId else {
            fatalError("callId is not set.")
        }
        self.webSocket.delegate = self
        self.webSocket.connect()
        logger.info("ℹ️ subscribe channel: \(callId)")
    }
    
    public func send(sdp rtcSdp: RTCSessionDescription) {
        guard let callId = webSocket.callId else {
            logger.error("❌ callId is not set.")
            return
        }
        
        let message = SignalMessage(type: .sdp(SessionDescription(from: rtcSdp)), senderId: clientId, callId: callId)
        do {
            let dataMessage = try self.encoder.encode(message)
            self.webSocket.send(data: dataMessage)
        } catch let error {
            logger.warning("⚠️ Couldn't encode sdp: \(error)")
        }
    }
    
    public func send(candidate rtcIceCandidate: RTCIceCandidate) {
        guard let callId = webSocket.callId else {
            logger.error("❌ callId is not set.")
            return
        }
        
        let message = SignalMessage(type: .candidate(IceCandidate(from: rtcIceCandidate)), senderId: clientId, callId: callId)
        do {
            let dataMessage = try self.encoder.encode(message)
            self.webSocket.send(data: dataMessage)
        } catch let error {
            logger.warning("⚠️ Couldn't encode candidate: \(error)")
        }
    }
    
    public func sendBye() {
        guard let callId = webSocket.callId else {
            logger.error("❌ callId is not set.")
            return
        }
        
        let message = SignalMessage(type: .bye, senderId: clientId, callId: callId)
        do {
            let dataMessage = try self.encoder.encode(message)
            self.webSocket.send(data: dataMessage)
        } catch let error {
            logger.warning("⚠️ Couldn't encode bye: \(error)")
        }
    }
    
    public func close() {
        self.webSocket.close()
    }
    
    public func start() {
        self.webSocket.start()
    }
}

extension SignalingClient: WebSocketProviderDelegate {
    func webSocketDidConnect(_ webSocket: WebSocketProvider) {
        self.delegate?.signalClientDidConnect(self)
    }
    
    func webSocketDidDisconnect(_ webSocket: WebSocketProvider) {
        self.delegate?.signalClientDidDisconnect(self)
        
        // try to reconnect every two seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            self.logger.debug("Trying to reconnect to signaling server...")
            self.webSocket.connect()
        }
    }
    
    func webSocket(_ webSocket: WebSocketProvider, didReceiveData data: Data) {
        do {
            let signal = try self.decoder.decode(SignalMessage.self, from: data)
            guard signal.senderId != clientId else { return }
            
            switch signal.type {
            case .candidate(let iceCandidate):
                self.delegate?.signalClient(self, didReceiveCandidate: iceCandidate.rtcIceCandidate)
            case .sdp(let sessionDescription):
                self.delegate?.signalClient(self, didReceiveRemoteSdp: sessionDescription.rtcSessionDescription)
            case .bye:
                self.delegate?.signalClientDidReceiveBye(self)
            }
        } catch let error {
            logger.warning("⚠️ Couldn't decode incoming message: \(error)")
        }
    }
    
    func webSocketDidError(_ webSocket: any WebSocketProvider, didError error: Error) {
        logger.error("❌ Failed to connect to the signaling server: \(error)")
    }
}
