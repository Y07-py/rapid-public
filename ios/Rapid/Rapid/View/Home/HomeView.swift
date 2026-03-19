//
//  HomeView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/10.
//

import Foundation
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var recruitmentViewModel: RecruitmentViewModel
    @EnvironmentObject private var voiceChatViewModel: VoiceChatViewModel
    
    @StateObject private var locationSelectViewModel = LocationSelectViewModel()
    
    @State private var selection: Int = .zero
    @State private var recruitmentCover: Bool = false
    @State private var detailCover: Bool = false
    @State private var candidateCover: Bool = false
    
    // Voice chat property
    @State private var callAlertModel: CallAlertModel? = nil
    @State private var isShowVideoView: Bool = false
    @State private var signalingClient: SignalingClient? = nil
    @State private var greetMessage: GreetMessage? = nil
    @State private var callId: String = ""
    @State private var clientId: String = ""
    @State private var opponentName: String? = nil
    @State private var opponentImageURL: URL? = nil
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            HomeTabViewRepresentable(selection: $selection) {
                TabItem(title: "", systemImage: "square.stack") {
                    RecruitmentRootView()
                        .environmentObject(recruitmentViewModel)
                }
                TabItem(title: "", systemImage: "waveform") {
                    VoiceChatView()
                        .environmentObject(voiceChatViewModel)
                }
                TabItem(title: "", systemImage: "square.and.pencil") {
                    MakeRecruitmentRootView(
                        recruitmentCover: $recruitmentCover,
                        detailCover: $detailCover,
                        candidateCover: $candidateCover
                    )
                    .environmentObject(locationSelectViewModel)
                }
                TabItem(title: "", systemImage: "message") {
                    ChatView()
                        .environmentObject(chatViewModel)
                }
                TabItem(title: "", systemImage: "person") {
                    ProfileRootView()
                        .environmentObject(profileViewModel)
                }
            }
            .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: .performAnswerCallNotification, object: nil), perform: { publisher in
            Task { @MainActor in
                let callUUID = publisher.userInfo?["callUUID"] as? UUID
                let callId = callUUID?.uuidString.lowercased() ?? ""
                let callerName = publisher.userInfo?["callerName"] as? String
                let callerHandle = publisher.userInfo?["handle"] as? String
                
                // Fetch session if profileViewModel is not ready
                let session = await SupabaseManager.shared.getSession()
                guard let myId = session?.user.id.uuidString.lowercased() else { return }
                
                let provider = SupabaseRealtimeProvider(callId: callId)
                self.signalingClient = SignalingClient(clientId: myId, webSocket: provider)
                self.callId = callId
                self.clientId = myId
                self.opponentName = callerName
                
                if let userId = callerHandle {
                    do {
                        let profileURLs = try await SupabaseManager.shared.getPresignURLFromStorage(
                            bucket: "profile",
                            folder: "users/\(userId.lowercased())"
                        )
                        self.opponentImageURL = profileURLs.values.first
                    } catch {
                        print("❌ Failed to fetch caller profile image: \(error.localizedDescription)")
                    }
                }
                
                // IMPORTANT: connect to signaling server
                self.signalingClient?.connect()
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowVideoView.toggle()
                }
            }
        })
        .fullScreenCover(isPresented: $recruitmentCover, content: {
            RecruitmentEditorRootView(firstRoot: .editor, isShowScreen: $recruitmentCover, viewType: .firstView)
                .environmentObject(locationSelectViewModel)
        })
        .fullScreenCover(isPresented: $detailCover) {
            RecruitmentEditorRootView(firstRoot: .detail, isShowScreen: $detailCover, viewType: .secondView)
                .environmentObject(locationSelectViewModel)
        }
        .fullScreenCover(isPresented: Binding(
            get: { isShowVideoView || voiceChatViewModel.isShowCallView },
            set: { newValue in
                if !newValue {
                    isShowVideoView = false
                    voiceChatViewModel.isShowCallView = false
                }
            }
        ), content: {
            if voiceChatViewModel.isShowCallView {
                VoiceChatCallView(
                    isPresented: $voiceChatViewModel.isShowCallView,
                    signalingClient: voiceChatViewModel.signalingClient,
                    clientId: voiceChatViewModel.signalingClient?.clientId ?? "",
                    callId: voiceChatViewModel.currentCallId,
                    role: voiceChatViewModel.currentCallRole,
                    opponentName: voiceChatViewModel.callOpponentName,
                    opponentImageURL: voiceChatViewModel.callOpponentImageURL
                )
                .environmentObject(voiceChatViewModel)
            } else {
                VoiceChatCallView(
                    isPresented: $isShowVideoView,
                    signalingClient: signalingClient,
                    clientId: clientId,
                    callId: callId,
                    role: .callee,
                    opponentName: opponentName,
                    opponentImageURL: opponentImageURL
                )
                .environmentObject(voiceChatViewModel)
            }
        })
        .sheet(isPresented: $candidateCover, content: {
            LocationCandidateView(candidateCover: $candidateCover)
                .environmentObject(locationSelectViewModel)
                .presentationDetents([.fraction(0.95)])
        })
        .onAppear {
            Task {
                await locationSelectViewModel.searchSelectLocation()
            }
        }
    }
}
