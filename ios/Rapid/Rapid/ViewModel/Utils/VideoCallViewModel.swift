//
//  VideoCallViewModel.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/14.
//

import Foundation
import SwiftUI
import WebRTC

public enum CallingRole: Equatable {
    /// Use to identify which device is initiating the call at the start of the call.
    case caller
    case callee
}

final public class VideoCallViewModel: ObservableObject {
    @Published var remainingTime: TimeInterval = 600 // 10 minutes
    @Published var connectionState: RTCIceConnectionState = .new {
        didSet {
            if connectionState == .connected {
                self.startTimer()
            } else if connectionState == .disconnected || connectionState == .failed || connectionState == .closed {
                self.stopTimer()
            }
        }
    }
    @Published var isMuted: Bool = false
    @Published var isSpeakOn: Bool = true
    @Published var isHello: Bool = false
    @Published var isCallEnded: Bool = false
    
    private let callId: String
    private let role: CallingRole
    
    
    private let webRTCClient: WebRTCClient
    private let signalingClient: SignalingClient?
    
    private let logger = Logger.shared
    
    private var signalingConnected: Bool = false
    private var hasRemoteSdp: Bool = false
    private var localCandidateCount: Int = 0
    private var remoteCandidateCount: Int = 0
    private var callingID: String? = nil
    private var timer: Timer? = nil
    
    // Buffer to temporarily store remote candidates until remote SDP is set.
    private var remoteCandidatesBuffer: [RTCIceCandidate] = []
    
    
    // Renderer
//    public var localRenderer: RTCEAGLVideoView = .init()
//    public var remoteRenderer: RTCEAGLVideoView = .init()
    
    init(
        signalingClient: SignalingClient?,
        callId: String,
        role: CallingRole
    ) {
        self.callId = callId
        self.role = role
        
        // SignalingClient
        self.signalingClient = signalingClient
        
        // WebRTCClient
        // ice servers list is quoted from the following site. https://gist.github.com/sagivo/3a4b2f2c7ac6e1b5267c2f1f59ac6c6b
        self.webRTCClient = WebRTCClient(iceServers: Config.default.webRTCIceServers)
        
        self.signalingClient?.delegate = self
        self.webRTCClient.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEndCall(_:)),
            name: .performEndCallNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAnswerCall(_:)),
            name: .performAnswerCallNotification,
            object: nil
        )
    }
    
    private func startTimer() {
        guard self.timer == nil else { return }
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.remainingTime > 0 {
                    self.remainingTime -= 1
                } else {
                    self.close()
                }
            }
        }
    }
    
    private func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }

    @objc private func handleEndCall(_ notification: Notification) {
        self.close()
    }
    
    @objc private func handleAnswerCall(_ notification: Notification) {
        self.answer()
    }
    
    // Call start flow
    public func startOffer() {
        do {
            try AudioSessionManager.shared.configureForCall()
            try AudioSessionManager.shared.activate()
        } catch let error {
            logger.error("❌ Failed to configure audio session: \(error)")
            return
        }
                
        if role == .caller {
            self.webRTCClient.offer { [weak self] sdp in
                guard let self = self else { return }
                self.signalingClient?.send(sdp: sdp)
            }
        }
    }
    
    public func stopOffer() {
        AudioSessionManager.shared.deactivate()
    }
    
    public func answer() {
        self.webRTCClient.answer { sdp in
            self.signalingClient?.send(sdp: sdp)
        }
    }
    
    public func close() {
        self.signalingClient?.sendBye()
        self.signalingClient?.close()
        self.webRTCClient.close()
        self.stopTimer()
        self.isCallEnded = true
    }
    
    public func toggleMute() {
        self.isMuted.toggle()
        if self.isMuted {
            self.webRTCClient.muteAudio()
        } else {
            self.webRTCClient.unmuteAudio()
        }
    }
    
    public func toggleSpeaker() {
        if self.isSpeakOn {
            self.webRTCClient.speakerOff()
        } else {
            self.webRTCClient.speakerOn()
        }
        self.isSpeakOn.toggle()
    }
    
    public func formatRemainingTime() -> String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension VideoCallViewModel: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        self.localCandidateCount += 1
        self.signalingClient?.send(candidate: candidate)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        switch state {
        case .closed:
            // If connection state is close, this state is broadcast.
            self.signalingClient?.close()
        case .checking:
            print("checking")
        case .disconnected:
            print("disconnected")
            self.signalingClient?.close()
        case .completed:
            print("completed")
        case .failed:
            print("faild")
            self.signalingClient?.close()
        default:
            break
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {}
}

extension VideoCallViewModel: SignalingClientDelegate {
    func signalClientDidConnect(_ signalClient: SignalingClient) {
        self.signalingConnected = true
        self.signalingClient?.start()
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        self.signalingConnected = false
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        self.webRTCClient.set(remoteSdp: sdp) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.logger.warning("⚠️ setting remote sdp failed: \(error.localizedDescription)")
                return
            }
            
            self.hasRemoteSdp = true
            
            // Apply all buffered candidates after remote SDP is successfully set.
            for candidate in self.remoteCandidatesBuffer {
                self.webRTCClient.set(remoteCandidate: candidate)
            }
            self.remoteCandidatesBuffer.removeAll()
        }
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate) {
        if self.hasRemoteSdp {
            // Add candidate directly if remote SDP is already set.
            self.webRTCClient.set(remoteCandidate: candidate)
        } else {
            // Buffer candidate if remote SDP has not been set yet.
            self.remoteCandidatesBuffer.append(candidate)
        }
        self.remoteCandidateCount += 1
    }
    
    func signalClientDidReceiveBye(_ signalClient: SignalingClient) {
        self.logger.info("ℹ️ Received Bye signal from remote (VideoCallViewModel)")
        self.webRTCClient.close()
        self.stopTimer()
        DispatchQueue.main.async {
            self.isCallEnded = true
        }
    }
}
