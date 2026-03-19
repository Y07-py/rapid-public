//
//  MainRootView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/10.
//

import Foundation
import SwiftUI

enum MainRoot {
    case login
    case home
}

struct MainRootView: View {
    @StateObject private var mainRootViewModel: RootViewModel<MainRoot>
    
    init(mainRoot: MainRoot) {
        self._mainRootViewModel = StateObject(wrappedValue: RootViewModel(root: mainRoot))
    }
    
    var body: some View {
        RootViewController(rootViewModel: mainRootViewModel, animationStyle: .vertical) { root in
            switch root {
            case .login:
                LoginRootView()
            case .home:
                HomeRootView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushRootViewNotification, object: nil), perform: { publisher in
            if let mainRoot = publisher.userInfo?["root"] as? MainRoot {
                self.mainRootViewModel.push(mainRoot)
            }
        })
        .environmentObject(mainRootViewModel)
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea()
        
    }
}

