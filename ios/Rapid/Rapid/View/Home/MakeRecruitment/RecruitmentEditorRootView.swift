//
//  RecruitmentEditorRootView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/02.
//

import Foundation
import SwiftUI

public enum RecruitmentEditorRoot: Equatable {
    case editor
    case detail
    case candidateList
}

struct RecruitmentEditorRootView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @StateObject private var rootViewModel: RootViewModel<RecruitmentEditorRoot>
    
    @Binding var isShowScreen: Bool
    
    private let viewType: RecruitmentEditorViewType
    
    init(firstRoot: RecruitmentEditorRoot, isShowScreen: Binding<Bool>, viewType: RecruitmentEditorViewType) {
        self._rootViewModel = StateObject(wrappedValue: RootViewModel(root: firstRoot))
        self._isShowScreen = isShowScreen
        self.viewType = viewType
    }
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            RootViewController(rootViewModel: rootViewModel) { root in
                switch root {
                case .editor: RecruitmentEditorView(isShowScreen: $isShowScreen, viewType: viewType)
                case .detail: LocationDetailView(isShowScreen: $isShowScreen, viewMode: .notCandidate)
                case .candidateList: LocationSelectedListView(isShowScreen: $isShowScreen)
                }
            }
            .environmentObject(locationSelectViewModel)
            .environmentObject(rootViewModel)
        }
        .ignoresSafeArea()
    }
}
