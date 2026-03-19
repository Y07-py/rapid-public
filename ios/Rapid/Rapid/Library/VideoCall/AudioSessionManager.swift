//
//  AudioSessionManager.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/12.
//

import Foundation
import AVFAudio

public final class AudioSessionManager: NSObject {
    /// A class for performing basic call settings from start to finish to enable voice calls. However, muting functionality is delegated to WebClient
    /// WebRTC itself provides a mechanism for receiving audio using the camera and microphone, but the purpose of this class is to handle
    /// OS-level adjustments such as obtaining the right to access the microphone and determine which speaker to output sound from.
    
    static let shared = AudioSessionManager()
    private let session = AVAudioSession.sharedInstance()
    private let logger = Logger.shared
    private override init() { super.init() }
    
    private var sampleRate: Double = 48_000
    private var bufferDuration: TimeInterval = 0.01
}

// MARK: - Property set
extension AudioSessionManager {
    public func setSampleRate(_ sampleRate: Double) {
        self.sampleRate = sampleRate
    }
    
    public func setBufferDuration(_ bufferDuration: TimeInterval) {
        self.bufferDuration = bufferDuration
    }
}

// MARK: - Audio Session
extension AudioSessionManager {
    public func configureForCall() throws {
        /// this function call at once, when before calling. to setting some mode for audio session.
        try session.setCategory(.playAndRecord,
                                mode: .voiceChat,
                                options: [AVAudioSession.CategoryOptions.allowBluetoothHFP,
                                          .allowBluetoothA2DP,
                                          .defaultToSpeaker])
        
        // WebRTC is often use 48 kHz
        try session.setPreferredSampleRate(sampleRate)
        // IO buffer 10ms or so.
        try session.setPreferredIOBufferDuration(bufferDuration)
        registerForNotifications()
    }
    
    // activate before start audio communication. it is need to background connection.
    public func activate() throws {
        try session.setActive(true, options: [])
    }
    
    // invalidate when finish audio communication.
    public func deactivate() {
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch let error {
            logger.error("❌ AVAudioSession deactivate error: \(error)")
        }
    }
    
    // forced switch speaker
    public func setSpeaker(_ on: Bool) {
        do {
            try session.overrideOutputAudioPort(on ? .speaker : .none)
        } catch let error {
            logger.error("❌ overrideOutputAudioPort error: \(error)")
        }
    }
    
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification,
                                               object: session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRouteChange(_:)),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMediaServicesWereReset(_:)),
                                               name: AVAudioSession.mediaServicesWereResetNotification,
                                               object: session)
    }
    
    private func unregisterNotifications() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: session)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: session)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.mediaServicesWereResetNotification, object: session)
    }
    
    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            logger.info("ℹ️ Audio interruption began.")
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt
            let optionsRaw = optionsValue ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            let shouldResume = options.contains(.shouldResume)
            
            if shouldResume {
                do {
                    // reactivate if available
                    try session.setActive(true)
                } catch let error {
                    logger.error("❌ Failed re-activating error: \(error)")
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(_ note: Notification) {
        guard let info = note.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        
        logger.info("ℹ️ Audio route changed: \(reason)")
    }

    @objc private func handleMediaServicesWereReset(_ note: Notification) {
        logger.info("ℹ️ Media services were reset. Reconfiguring audio session…")
        do {
            try configureForCall()
            try activate()
        } catch {
            logger.error("❌ Failed to reconfigure audio session after reset: \(error)")
        }
    }
}

