//
//  LocationSearchRootView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/14.
//

import Foundation
import SwiftUI

public enum LocationSearchRoot: Equatable {
    case filter
    case map
}

struct LocationSearchRootView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    @StateObject private var locationSearchRootViewModel = RootViewModel<LocationSearchRoot>(root: .filter)
    
    @Binding var isShowFieldView: Bool
    
    @State private var searchResults: [GooglePlacesSearchPlaceWrapper] = []
    @State private var query: String = ""
    
    var body: some View {
        ZStack {
            RootViewController(rootViewModel: locationSearchRootViewModel) { root in
                switch root {
                case .filter:
                    LocationSearchFieldView(isShowFieldView: $isShowFieldView, searchResults: $searchResults, query: $query)
                case .map:
                    LocationSearchMapView(isShowFieldView: $isShowFieldView, searchResults: $searchResults, query: $query)
                }
            }
            .environmentObject(locationSelectViewModel)
            .environmentObject(locationSearchRootViewModel)
            .navigationBarBackButtonHidden(true)
        }
        .ignoresSafeArea()
    }
}
