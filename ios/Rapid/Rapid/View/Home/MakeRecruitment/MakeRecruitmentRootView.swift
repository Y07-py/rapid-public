//
//  MakeRecruitmentView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/21.
//

import Foundation
import SwiftUI

enum MakeRecruitmentRoot: Hashable {
    case select
}

struct MakeRecruitmentRootView: View {
    @StateObject private var makeRecruitmentRootViewModel: RootViewModel<MakeRecruitmentRoot> = .init(root: .select)
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    @Binding var recruitmentCover: Bool
    @Binding var detailCover: Bool
    @Binding var candidateCover: Bool
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            RootViewController(rootViewModel: makeRecruitmentRootViewModel) { root in
                switch root {
                case .select:
                    LocationSelectView(
                        recruitmentCover: $recruitmentCover,
                        detailCover: $detailCover,
                        candidateCover: $candidateCover
                    )
                }
            }
            .environmentObject(makeRecruitmentRootViewModel)
            .environmentObject(locationSelectViewModel)
            .navigationBarBackButtonHidden(true)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}
