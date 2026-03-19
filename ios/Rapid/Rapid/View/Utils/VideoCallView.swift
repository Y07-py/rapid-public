//
//  VideoCallView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/11/14.
//

import Foundation
import SwiftUI
import WebRTC


struct VideoCallView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @StateObject private var videoCallViewModel: VideoCallViewModel
    @Binding var isPresented: Bool
    private var role: CallingRole
    
    init(
        isPresented: Binding<Bool>,
        signalingClient: SignalingClient?,
        clientId: String,
        callId: String,
        role: CallingRole
    ) {
        self._videoCallViewModel = StateObject(wrappedValue: VideoCallViewModel(signalingClient: signalingClient, callId: callId, role: role))
        self._isPresented = isPresented
        self.role = role
    }
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            VStack {
                Spacer()
            }
            .overlay(alignment: .bottom) {
                controllerBar
            }
        }
        .onAppear {
            switch self.role {
            case .caller:
                self.videoCallViewModel.startOffer()
            case .callee:
                self.videoCallViewModel.answer()
            }
        }
    }
    
    @ViewBuilder
    private var controllerBar: some View {
        HStack(alignment: .center, spacing: .zero) {
            Spacer()
            Button(action: {
                withAnimation {
                    self.videoCallViewModel.toggleMute()
                }
            }) {
                Circle()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.white)
                    .overlay(alignment: .center) {
                        if self.videoCallViewModel.isMuted {
                            Image(systemName: "speaker.fill")
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.black)
                        } else {
                            Image(systemName: "speaker.slash.fill")
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.black)
                        }
                    }
            }
            Spacer()
            Button(action: {
                withAnimation {
                    self.videoCallViewModel.toggleSpeaker()
                }
            }) {
                Circle()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.white)
                    .overlay(alignment: .center) {
                        if self.videoCallViewModel.isSpeakOn {
                            Image(systemName: "microphone.slash.fill")
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.black)
                        } else {
                            Image(systemName: "microphone.fill")
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.black)
                        }
                    }
            }
            Spacer()
            Button(action: {
                self.videoCallViewModel.close()
                self.chatViewModel.callAlert = false
                withAnimation {
                    self.isPresented = false
                }
            }) {
                Circle()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.red)
                    .overlay(alignment: .center) {
                        Image(systemName: "phone.down.fill")
                            .frame(width: 40, height: 40)
                            .foregroundStyle(.white)
                    }
            }
        }
        .padding(.horizontal, 20)
    }
}
