//
//  RecruitmentRootView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/10/13.
//

import Foundation
import SwiftUI

public enum RecruitmentRoot: Equatable {
    case main
}

struct RecruitmentRootView: View {
    @EnvironmentObject private var recruitmentViewModel: RecruitmentViewModel
    @StateObject private var recruitmentRootViewModel = RootViewModel<RecruitmentRoot>(root: .main)
    
    var body: some View {
        ZStack {
            RootViewController(rootViewModel: recruitmentRootViewModel) { root in
                switch root {
                case .main: RecruitmentView()
                        .environmentObject(recruitmentRootViewModel)
                }
            }
            .navigationBarBackButtonHidden(true)
            .ignoresSafeArea()
        }
    }
}
