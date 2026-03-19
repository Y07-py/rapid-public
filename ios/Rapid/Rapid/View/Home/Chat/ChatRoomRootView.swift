//
//  ChatRoomRootView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/08.
//

import Foundation
import SwiftUI

public enum ChatRoomRoot: Equatable {
    case room
    case setting
    case report
}

struct ChatRoomRootView: View {
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    @StateObject private var chatRoomRootViewModel = RootViewModel<ChatRoomRoot>(root: .room)
    @StateObject private var chatRoomViewModel: ChatRoomViewModel

    let chatViewModel: ChatViewModel

    init(chatViewModel: ChatViewModel) {
        self.chatViewModel = chatViewModel
        _chatRoomViewModel = StateObject(wrappedValue: ChatRoomViewModel(chatViewModel: chatViewModel))
    }

    var body: some View {
        ZStack {
            RootViewController(rootViewModel: chatRoomRootViewModel) { root in
                switch root {
                case .room:
                    ChatRoomView()
                case .setting:
                    ChatRoomSettingView()
                case .report:
                    ChatRoomReportReasonView()
                }
            }
            .environmentObject(chatRoomRootViewModel)
            .environmentObject(homeRootViewModel)
            .environmentObject(chatViewModel)
            .environmentObject(chatRoomViewModel)
            .environmentObject(profileViewModel)
            .navigationBarBackButtonHidden(true)
            .ignoresSafeArea()
        }
    }
}
