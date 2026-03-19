//
//  LocationSearchMapView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/14.
//

import Foundation
import SwiftUI
import GoogleMaps
import PopupView
import SDWebImageSwiftUI

struct LocationSearchMapView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @Binding var isShowFieldView: Bool
    @Binding var searchResults: [GooglePlacesSearchPlaceWrapper]
    @Binding var query: String
    
    @State private var isShowSearchFieldView: Bool = false
    @State private var isShowResultListView: Bool = true
    @State private var currentPresentationDetent: PresentationDetent = .height(60)
    @State private var searchResultOffset: Int = 0
    @State private var isShowFilterConfig: Bool = false
    
    
    var body: some View {
        ZStack {
            if let location = locationSelectViewModel.userLocation {
                GMSLocationSearchViewRepresentable(searchResults: $searchResults, location: location)
                    .ignoresSafeArea()
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.8))
                    .skelton(isActive: true)
                    .ignoresSafeArea()
            }
            
            VStack(alignment: .center, spacing: .zero) {
                headerView
                    .zIndex(1)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .sheet(isPresented: $isShowResultListView) {
                LocationSearchResultListView(
                    query: $query,
                    searchResults: $searchResults,
                    presentationDetent: $currentPresentationDetent,
                    searchResultOffset: $searchResultOffset
                )
                .environmentObject(locationSelectViewModel)
                .interactiveDismissDisabled(true)
                .presentationDetents([.height(60), .medium, .large], selection: $currentPresentationDetent)
                .presentationBackgroundInteraction(.enabled)
                .presentationContentInteraction(.scrolls)
            }
            .popup(item: $locationSelectViewModel.selectedLocation) { item in
                selectedLocationView(wrapper: item)
            } customize: { view in
                view
                    .type(.floater())
                    .appearFrom(.bottomSlide)
                    .position(.bottom)
            }

        }
        .fullScreenCover(isPresented: $isShowSearchFieldView) {
            LocationSearchMapFieldView(isShowFieldView: $isShowSearchFieldView)
                .environmentObject(locationSelectViewModel)
                .environmentObject(profileViewModel)
        }
        .onChange(of: locationSelectViewModel.selectedLocation) { _, newValue in
            if newValue != nil {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowResultListView = false
                }
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowResultListView = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func selectedLocationView(wrapper: GooglePlacesSearchPlaceWrapper) -> some View {
        VStack(alignment: .center, spacing: 10) {
            if let place = wrapper.place {
                Group {
                    if let photo = place.photos?.first {
                        WebImage(url: photo.buildUrl()) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 0)
                                .foregroundStyle(.gray.opacity(0.8))
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .skelton(isActive: true)
                        }
                    } else {
                        Image("NoPlaceImage")
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                    }
                }
                .overlay(alignment: .top) {
                    HStack(alignment: .center) {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                self.locationSelectViewModel.selectedPlace = nil
                                self.isShowResultListView = true
                            }
                        }) {
                            Circle()
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.white)
                                .overlay(alignment: .center) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.black.opacity(0.8))
                                }
                                .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                                .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding([.horizontal, .top], 10)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(place.displayName?.text ?? "No Name")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.black.opacity(0.8))
                        Spacer()
                    }
                    
                    HStack {
                        Text(place.formattedAddress ?? "")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.gray)
                        Spacer()
                    }
                }
                .padding([.horizontal, .bottom], 15)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
        .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowFieldView.toggle()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(width: 48, height: 48)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.gray)
                    .padding(.leading, 12)
                
                if query.isEmpty {
                    Text("現在地からの検索")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black.opacity(0.8))
                } else {
                    Text(query)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black.opacity(0.8))
                }
                Spacer()
            }
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowSearchFieldView.toggle()
                }
            }
            
            Button(action: {
                isShowFilterConfig = true
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(width: 48, height: 48)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .sheet(isPresented: $isShowFilterConfig) {
            LocationSearchFilterSheetView(
                query: $query,
                searchResults: $searchResults,
                isPresented: $isShowFilterConfig
            )
                .environmentObject(locationSelectViewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

fileprivate struct LocationSearchFilterSheetView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @Binding var query: String
    @Binding var searchResults: [GooglePlacesSearchPlaceWrapper]
    @Binding var isPresented: Bool
    
    @State private var isShowCategoryList: Bool = false
    @State private var isShowSearchRangeList: Bool = false
    
    @State private var isShowPointPayWallAlert: Bool = false
    @State private var isShowPointPayWall: Bool = false
    
    @FocusState private var focus: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.secondaryBackgroundColor
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        self.focus = false
                    }
                }
            
            VStack(alignment: .leading, spacing: 24) {
                Text("検索フィルター")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
                    .padding(.top, 32)
                
                // Search Bar (Unified with original: Icon on the right, separate button)
                HStack(spacing: 12) {
                    HStack(spacing: 12) {
                        TextField("店名やキーワードを入力", text: $query)
                            .focused($focus)
                            .font(.system(size: 16, weight: .medium))
                            .submitLabel(.search)
                            .onSubmit {
                                locationSearch()
                            }
                        
                        if !query.isEmpty {
                            Button(action: { query = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(Color.backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
                    
                    Button(action: locationSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.mainColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
                    }
                }
                
                VStack(spacing: 16) {
                    filterButton(
                        title: "カテゴリ",
                        subtitle: selectedCategoriesText,
                        icon: "tag.fill",
                        color: .orange
                    ) {
                        isShowCategoryList = true
                    }
                    .sheet(isPresented: $isShowCategoryList) {
                        SearchCategoryListView()
                            .environmentObject(locationSelectViewModel)
                            .presentationDetents([.medium, .large])
                            .presentationDragIndicator(.visible)
                    }
                    
                    filterButton(
                        title: "検索範囲",
                        subtitle: searchRadiusFormat(radius: locationSelectViewModel.searchRadius),
                        icon: "mappin.and.ellipse",
                        color: .blue
                    ) {
                        isShowSearchRangeList = true
                    }
                    .sheet(isPresented: $isShowSearchRangeList) {
                        SearchRangeView()
                            .environmentObject(locationSelectViewModel)
                            .presentationDetents([.height(280)])
                            .presentationDragIndicator(.visible)
                    }
                }
                
                // History Card
                if !locationSelectViewModel.searchQueries.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("最近の検索")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black.opacity(0.7))
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 8) {
                                ForEach(locationSelectViewModel.searchQueries) { history in
                                    HStack(spacing: 12) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.gray.opacity(0.8))
                                        
                                        Text(history.query)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.black.opacity(0.8))
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            withAnimation(.spring()) {
                                                locationSelectViewModel.deleteSearchQuery(query: history)
                                            }
                                        }) {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.gray.opacity(0.6))
                                                .padding(8)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.backgroundColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture {
                                        query = history.query
                                        locationSearch()
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    }
                    .padding(20)
                    .background(Color.secondaryBackgroundColor.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .alert("ポイントが不足しています", isPresented: $isShowPointPayWallAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("チャージする") {
                isShowPointPayWall = true
            }
        } message: {
            Text("検索を実行するにはポイントが不足しています。ポイントをチャージしますか？")
        }
        .fullScreenCover(isPresented: $isShowPointPayWall) {
            PointPurchasePayWallView(isPresented: $isShowPointPayWall)
                .environmentObject(profileViewModel)
        }
    }
    
    private var selectedCategoriesText: String {
        let selected = locationSelectViewModel.selectedLocationCategory
        if selected.isEmpty {
            return "指定なし"
        } else if selected.count == 1 {
            return selected[0].name
        } else {
            return "\(selected[0].name) + \(selected.count - 1)"
        }
    }
    
    @ViewBuilder
    private func filterButton(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray)
                    Text(subtitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.5))
            }
            .padding(16)
            .background(Color.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
    
    private func searchRadiusFormat(radius: Double) -> String {
        if radius < 1000 {
            return String(format: "%.0fm以内", radius)
        } else {
            let km = radius / 1000
            return String(format: "%.1fkm以内", km)
        }
    }
    
    private func locationSearch() {
        if profileViewModel.totalPoint - 10 < 0 {
            isShowPointPayWallAlert = true
            return
        }
        
        focus = false
        Task {
            self.searchResults = await self.locationSelectViewModel.locationSearch(query: query, offset: 0)
            withAnimation {
                self.isPresented = false
            }
        }
    }
}

fileprivate struct LocationSearchResultListView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    @Binding var query: String
    @Binding var searchResults: [GooglePlacesSearchPlaceWrapper]
    @Binding var presentationDetent: PresentationDetent
    @Binding var searchResultOffset: Int
    
    @State private var searchResultTopOffset: CGFloat = 100
    @State private var scrollPosition: Int?
    @State private var isShowDetail: Bool = false
    
    @StateObject private var dummyRootViewModel = RootViewModel<RecruitmentEditorRoot>(root: .detail)
    
    var body: some View {
        ZStack {
            Color.secondaryBackgroundColor.ignoresSafeArea()
            VStack(alignment: .center, spacing: .zero) {
                HStack(alignment: .center) {
                    Spacer()
                    Text("検索結果")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.gray)
                    Spacer()
                }
                .padding(.top, 30)
                ScrollView(.vertical) {
                    VStack(alignment: .center, spacing: 4) {
                        ForEach(0..<searchResults.count, id: \.self) { idx in
                            let result = searchResults[idx]
                            if let place = result.place {
                                Button(action: {
                                    self.locationSelectViewModel.selectedPlace = result
                                    self.isShowDetail = true
                                }) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        if let photo = place.photos?.first {
                                            WebImage(url: photo.buildUrl()) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(height: 180)
                                                    .clipped()
                                            } placeholder: {
                                                Rectangle()
                                                    .foregroundStyle(.gray.opacity(0.2))
                                                    .frame(height: 180)
                                                    .skelton(isActive: true)
                                            }
                                        } else {
                                            Image("NoPlaceImage")
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 180)
                                                .clipped()
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(place.displayName?.text ?? "No Name")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.black.opacity(0.85))
                                                .lineLimit(1)
                                            
                                            HStack(alignment: .top, spacing: 4) {
                                                Image(systemName: "mappin.circle.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.selectedColor)
                                                    .padding(.top, 2)
                                                
                                                Text(place.formattedAddress ?? "")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(.gray)
                                                    .lineLimit(2)
                                            }
                                            
                                            if let rating = place.rating {
                                                HStack(alignment: .center) {
                                                    ratingTextView(rating: rating)
                                                    Spacer()
                                                }
                                                .padding(.top, 2)
                                            }
                                        }
                                        .padding(16)
                                        .background(Color.backgroundColor)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                .id(idx)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollPosition(id: $scrollPosition)
                .offset(y: searchResultTopOffset)
                .onChange(of: scrollPosition) { _, newValue in
                    guard let scrollIdx = newValue else { return }
                    if scrollIdx + 1 == searchResults.count {
                        Task {
                            searchResultOffset += 1
                            let results = await self.locationSelectViewModel.locationSearch(query: query, offset: searchResultOffset)
                            self.searchResults.append(contentsOf: results)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .fullScreenCover(isPresented: $isShowDetail) {
            LocationDetailView(isShowScreen: $isShowDetail, viewMode: .notCandidate)
                .environmentObject(locationSelectViewModel)
                .environmentObject(dummyRootViewModel)
        }
        .onChange(of: presentationDetent) { _, newValue in
            if newValue != .height(60) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.searchResultTopOffset = 20
                }
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.searchResultTopOffset = 100
                }
            }
        }
    }
    
    @ViewBuilder
    private func ratingTextView(rating: Double) -> some View {
        // normalize rating into 0.0 ~ 5.0
        let integer = Int(rating)
        let fraction = Int(round(rating.truncatingRemainder(dividingBy: 1)))
        let nonStars = 5 - integer - fraction
        HStack {
            Text(String(rating))
                .font(.caption)
            HStack(alignment: .center) {
                ForEach(0..<integer, id: \.self) { _ in
                    Image("Star")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 12, height: 12)
                }
                ForEach(0..<fraction, id: \.self) { _ in
                    Image("HalfStar")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 12, height: 12)
                    
                    ForEach(0..<nonStars, id: \.self) { _ in
                        Image("NonStar")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
    }
}

fileprivate struct GMSLocationSearchViewRepresentable: UIViewRepresentable {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    @Binding var searchResults: [GooglePlacesSearchPlaceWrapper]
    
    let location: UserLocation
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> GMSMapView {
        let zoom = locationSelectViewModel.zoom
        let camera = GMSCameraPosition(latitude: location.latitude, longitude: location.longitude, zoom: zoom)
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    func updateUIView(_ uiView: GMSMapView, context: Context) {
        context.coordinator.parent = self
        
        if context.coordinator.previousSearchResults != searchResults {
            uiView.clear()
            
            for result in searchResults {
                guard let location = result.place?.location,
                      let latitude = location.latitude,
                      let longitude = location.longitude else { continue }
                
                let marker = GMSMarker(position: .init(latitude: latitude, longitude: longitude))
                marker.map = uiView
            }
            
            if !searchResults.isEmpty {
                let zoom = locationSelectViewModel.zoom
                let (centerLat, centerLon) = self.computeCenterPosition(locations: searchResults)
                let coordinate = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
                let cameraUpdate = GMSCameraUpdate.setTarget(coordinate, zoom: zoom)
                
                uiView.moveCamera(cameraUpdate)
            }
            
            context.coordinator.previousSearchResults = searchResults
        }
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GMSLocationSearchViewRepresentable
        var previousSearchResults: [GooglePlacesSearchPlaceWrapper] = []
        
        init(parent: GMSLocationSearchViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard let wrapper = self.parent.searchResults.filter({
                $0.place?.location?.latitude == marker.position.latitude && $0.place?.location?.longitude == marker.position.longitude
            }).first else { return false }
            
            let cameraUpdate = GMSCameraUpdate.setTarget(marker.position)
            mapView.animate(with: cameraUpdate)
            
   
            self.parent.locationSelectViewModel.selectedLocationMarker(wrapper: wrapper)
            
            
            return false
        }
    }
    
    /// Compute center position from given location coordinates.
    private func computeCenterPosition(locations: [GooglePlacesSearchPlaceWrapper]) -> (Double, Double) {
        let points: [(x: Double, y: Double, z: Double)] = locations.compactMap { wrapper in
            guard let location = wrapper.place?.location,
                  let latitude = location.latitude,
                  let longitude = location.longitude else { return nil }
            
            let latRad = latitude * .pi / 180.0
            let lonRad = longitude * .pi / 180.0
            
            return (
                x: cos(latRad) * cos(lonRad),
                y: cos(latRad) * sin(lonRad),
                z: sin(latRad)
            )
        }
        
        let sumX = points.reduce(0.0) { $0 + $1.x }
        let sumY = points.reduce(0.0) { $0 + $1.y }
        let sumZ = points.reduce(0.0) { $0 + $1.z }
        
        let count = Double(points.count)
        let avgX = sumX / count
        let avgY = sumY / count
        let avgZ = sumZ / count
        
        let lonRad = atan2(avgY, avgX)
        let hyp = sqrt(avgX * avgX + avgY * avgY)
        let latRad = atan2(avgZ, hyp)
        
        return (latRad * 180.0 / .pi, lonRad * 180.0 / .pi)
    }
}

fileprivate struct LocationSearchMapFieldView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    @Binding var isShowFieldView: Bool
    
    @State private var query: String = ""
    
    // Category property
    @State private var isShowCategoryList: Bool = false
    
    // Search range property
    @State private var isShowSearchRangeList: Bool = false
    
    var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: .zero) {
                headerView
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center) {
                        Text("気になるロケーションは？")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.8))
                        Spacer()
                    }
                    HStack(alignment: .center, spacing: 15) {
                        TextField("ロケーションを検索", text: $query)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.gray.opacity(0.5), lineWidth: 1)
                            }
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                self.isShowFieldView.toggle()
                            }
                        }) {
                            Circle()
                                .frame(width: 50, height: 50)
                                .overlay(alignment: .center) {
                                    Image(systemName: "magnifyingglass")
                                        .frame(width: 40, height: 40)
                                        .foregroundStyle(Color.white)
                                }
                                .foregroundStyle(Color.mainColor)
                                .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                                .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
                            Image("categories")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 20, height: 20)
                                .foregroundStyle(.black.opacity(0.8))
                            VStack(alignment: .leading, spacing: 5) {
                                Text("カテゴリ")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.8))
                                Text("設定できるカテゴリは最大50個までです。")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.gray.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.gray.opacity(0.8))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                self.isShowCategoryList.toggle()
                            }
                        }
                        .sheet(isPresented: $isShowCategoryList) {
                            SearchCategoryListView()
                                .environmentObject(locationSelectViewModel)
                                .presentationDetents([.fraction(0.5)])
                        }
                        
                        FlowLayout(spacing: 10) {
                            let selectedCategoryList = self.locationSelectViewModel.selectedLocationCategory
                            ForEach(selectedCategoryList) { category in
                                HStack(alignment: .center, spacing: 5) {
                                    Text(category.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.black.opacity(0.8))
                                    Button(action: {
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            self.locationSelectViewModel.updateSelectedLocationCategories(category: category)
                                        }
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.gray.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 10)
                                }
                                .padding(10)
                                .background {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.gray.opacity(0.5), lineWidth: 1)
                                }
                            }
                        }
                    }
                    
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "paperplane.circle")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.black.opacity(0.8))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("検索範囲")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.black.opacity(0.8))
                            Text("最大検索距離は50kmです。")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.gray.opacity(0.8))
                        }
                        Spacer()
                        let searchRadius = locationSelectViewModel.searchRadius
                        Text(searchRadiusFormat(radius: searchRadius))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.black.opacity(0.8))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.gray.opacity(0.8))
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.isShowSearchRangeList.toggle()
                        }
                    }
                    .sheet(isPresented: $isShowSearchRangeList) {
                        SearchRangeView()
                            .environmentObject(locationSelectViewModel)
                            .presentationDetents([.fraction(0.5)])
                    }
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
                .padding(.horizontal, 10)
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        Text("検索履歴")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.black.opacity(0.8))
                        Spacer()
                    }
                    
                    ScrollView(.vertical) {
                        VStack(alignment: .center, spacing: .zero) {
                            
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                .padding()
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
                .padding(.horizontal, 10)
                .padding(.top, 20)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(.ultraThinMaterial)
        .ignoresSafeArea(.keyboard)
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .center) {
            Spacer()
            Button(action: {
                self.locationSelectViewModel.selectedLocationCategory.removeAll()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowFieldView.toggle()
                }
            }) {
                Circle()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.white)
                    .overlay(alignment: .center) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.black.opacity(0.8))
                    }
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                    .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private func searchRadiusFormat(radius: Double) -> String {
        if radius < 1000 {
            return String(format: "%.0fm", radius)
        } else {
            let km = radius / 1000
            return String(format: "%.1fkm", km)
        }
    }
}

fileprivate struct SearchCategoryListView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var categoryQuery: String = ""
    @State private var hitCategories: [LocationCategory] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)
                    TextField("カテゴリを検索 (例: カフェ, 公園)", text: $categoryQuery)
                }
                .padding()
                .background(Color.secondaryBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
                
                // Selected Preview
                if !locationSelectViewModel.selectedLocationCategory.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(locationSelectViewModel.selectedLocationCategory) { cat in
                                HStack(spacing: 4) {
                                    Text(cat.name)
                                    Button(action: {
                                        locationSelectViewModel.updateSelectedLocationCategories(category: cat)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.mainColor)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                
                List {
                    ForEach(hitCategories) { category in
                        Button(action: {
                            locationSelectViewModel.updateSelectedLocationCategories(category: category)
                        }) {
                            HStack {
                                Text(category.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.8))
                                Spacer()
                                if isSelected(category) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.mainColor)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("カテゴリ選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .onChange(of: categoryQuery) { _, newValue in
                hitCategories = locationSelectViewModel.searchCatgory(query: newValue)
            }
            .onAppear {
                hitCategories = locationSelectViewModel.locationCategories
            }
        }
    }
    
    private func isSelected(_ category: LocationCategory) -> Bool {
        locationSelectViewModel.selectedLocationCategory.contains(where: { $0.id == category.id })
    }
}

fileprivate struct SearchRangeView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text(searchRadiusFormat(radius: locationSelectViewModel.searchRadius))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color.mainColor)
                
                Text("検索する最大距離を指定します")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray)
            }
            .padding(.top, 20)
            
            Slider(value: $locationSelectViewModel.searchRadius, in: 500...50000, step: 500)
                .tint(Color.mainColor)
                .padding(.horizontal, 32)
            
            Button(action: { dismiss() }) {
                Text("設定する")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.mainColor)
                    .clipShape(Capsule())
                    .padding(.horizontal, 32)
            }
        }
        .padding(.bottom, 40)
    }
    
    private func searchRadiusFormat(radius: Double) -> String {
        if radius < 1000 {
            return String(format: "%.0fm", radius)
        } else {
            let km = radius / 1000
            return String(format: "%.1fkm", km)
        }
    }
}

