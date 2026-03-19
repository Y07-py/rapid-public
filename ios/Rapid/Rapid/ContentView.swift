//
//  ContentView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/06.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var contentViewModel = ContentViewModel()
    @StateObject private var userLocationViewModel = UserLocationViewModel()
    
    var body: some View {
        ZStack {
            switch contentViewModel.loginStatus {
            case .unknown:
                ThumbnailView()
            case .loggedIn:
                MainRootView(mainRoot: .home)
            case .loggedOut:
                MainRootView(mainRoot: .login)
            }
            
            if contentViewModel.isMaintenanceMode {
                MaintenanceView()
            }
        }
    }
}

#Preview {
    ContentView()
}
