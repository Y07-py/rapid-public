//
//  ProfileRootView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/09/25.
//

import Foundation
import SwiftUI

enum ProfileRoot: Equatable {
    case main
}

struct ProfileRootView: View {
    @StateObject private var profileRootViewModel = RootViewModel<ProfileRoot>(root: .main)
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    var body: some View {
        ZStack {
            RootViewController(rootViewModel: profileRootViewModel) { root in
                switch root {
                case .main:
                    ProfileView()
                }
            }
            .environmentObject(homeRootViewModel)
            .environmentObject(profileViewModel)
            .environmentObject(profileRootViewModel)
        }
        .ignoresSafeArea()
    }
}
