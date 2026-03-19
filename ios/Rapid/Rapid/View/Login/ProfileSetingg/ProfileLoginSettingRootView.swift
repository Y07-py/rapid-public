//
//  ProfileLoginSettingRootView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/12.
//

import Foundation
import SwiftUI

enum ProfileLoginSettingRoot: Equatable {
    case userName
    case gender
    case birthDay
    case height
    case living
    case keyword
    case introduction
    case profileImage
    case locationSearch
    case complete
}

struct ProfileLoginSettingRootView: View {
    @StateObject private var settingRootViewModel: RootViewModel<ProfileLoginSettingRoot> = .init(root: .userName)
    @StateObject private var profileLoginSettingViewModel = ProfileLoginSettingViewModel()
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            VStack(alignment: .center, spacing: 20) {
                ProgressView(value: profileLoginSettingViewModel.progress / 9)
                    .padding(.horizontal, 20)
                    .opacity(profileLoginSettingViewModel.progress == 15 ? 0.0 :  1.0)
                RootViewController(rootViewModel: settingRootViewModel) { root in
                    switch root {
                    case .userName: UserNameLoginSettingView()
                            .environmentObject(settingRootViewModel)
                            .environmentObject(profileLoginSettingViewModel)
                    case .gender: GenderLoginSettingView()
                            .environmentObject(settingRootViewModel)
                            .environmentObject(profileLoginSettingViewModel)
                    case .birthDay: BirthdayLoginSettingView()
                            .environmentObject(settingRootViewModel)
                            .environmentObject(profileLoginSettingViewModel)
                    case .height: HeightLoginSettingView()
                            .environmentObject(settingRootViewModel)
                            .environmentObject(profileLoginSettingViewModel)
                    case .living: LivingLoginSettingView()
                            .environmentObject(settingRootViewModel)
                            .environmentObject(profileLoginSettingViewModel)
                    case .keyword: KeyWordTagSettingView()
                            .environmentObject(settingRootViewModel)
                            .environmentObject(profileLoginSettingViewModel)
                    case .introduction: IntroductionSettingView()
                            .environmentObject(settingRootViewModel)
                            .environmentObject(profileLoginSettingViewModel)
                    case .profileImage: ProfileImageSettingView()
                            .environmentObject(settingRootViewModel)
                            .environmentObject(profileLoginSettingViewModel)
                    case .locationSearch: LocationSearchLoginSettingView()
                            .environmentObject(settingRootViewModel)
                            .environmentObject(profileLoginSettingViewModel)
                    case .complete: CompleteSettingView()
                            .environmentObject(settingRootViewModel)
                            .environmentObject(profileLoginSettingViewModel)
                    }
                }
                .navigationBarBackButtonHidden(true)
                .ignoresSafeArea()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
