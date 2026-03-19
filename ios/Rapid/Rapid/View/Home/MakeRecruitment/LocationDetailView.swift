//
//  LocationDetailView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/02.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import PopupView
import LinkPresentation

public enum DetailViewMode: Hashable {
    case notCandidate
    case candidate
}

struct LocationDetailView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @EnvironmentObject private var rootViewModel: RootViewModel<RecruitmentEditorRoot>
    
    @Binding var isShowScreen: Bool
    let viewMode: DetailViewMode
    
    @State private var scrollIdx: Int? = 0
    @State private var linkMetaData: LPLinkMetadata? = nil
    @State private var tapMapView: Bool = false
    @Namespace private var namespace
    
    private let days: [String] = ["日", "月", "火", "水", "木", "金", "土"]
    private let daysColor: [Color] = [.blue, .black, .black, .black, .black, .black, .red]
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.backgroundColor.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: .zero) {
                    // MARK: - Place photos
                    if let selectedPlace = locationSelectViewModel.selectedPlace {
                        let photos = selectedPlace.place?.photos ?? []
                        ZStack(alignment: .bottom) {
                            ScrollView(.horizontal) {
                                HStack(spacing: .zero) {
                                    if photos.isEmpty {
                                        Image("NoPlaceImage")
                                            .resizable()
                                            .scaledToFill()
                                            .containerRelativeFrame(.horizontal)
                                            .frame(height: 520)
                                            .clipped()
                                    } else {
                                        ForEach(0..<min(5, photos.count), id: \.self) { idx in
                                            let photo = photos[idx]
                                            WebImage(url: photo.buildUrl()) { image in
                                                image.resizable().scaledToFill()
                                            } placeholder: {
                                                Rectangle()
                                                    .foregroundStyle(.gray.opacity(0.1))
                                                    .skelton(isActive: true)
                                            }
                                            .containerRelativeFrame(.horizontal)
                                            .frame(height: 520)
                                            .clipped()
                                            .id(idx)
                                        }
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollPosition(id: $scrollIdx)
                            .scrollTargetBehavior(.paging)
                            .scrollIndicators(.hidden)
                            
                            if photos.count > 1 {
                                HStack(spacing: 6) {
                                    ForEach(0..<min(5, photos.count), id: \.self) { idx in
                                        Capsule()
                                            .frame(width: (scrollIdx ?? 0) == idx ? 20 : 6, height: 6)
                                            .foregroundStyle((scrollIdx ?? 0) == idx ? .white : .white.opacity(0.4))
                                            .animation(.spring(response: 0.3), value: scrollIdx)
                                    }
                                }
                                .padding(.bottom, 25)
                            }
                        }
                        .ignoresSafeArea(edges: .top)
                        
                        VStack(alignment: .leading, spacing: 32) {
                            // MARK: - Title and Address
                            VStack(alignment: .leading, spacing: 12) {
                                Text(selectedPlace.place?.displayName?.text ?? "不明なスポット")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.85))
                                
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.selectedColor)
                                    
                                    Text(selectedPlace.place?.formattedAddress ?? "住所情報なし")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.gray)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 25)
                            
                            // MARK: - Nearest transports
                            if !self.locationSelectViewModel.nearestTransports.isEmpty {
                                VStack(alignment: .leading, spacing: 15) {
                                    customSectionHeader(title: "最寄りの交通機関", icon: "train.side.front.car")
                                        .padding(.horizontal, 24)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(alignment: .center, spacing: 15) {
                                            let transports = self.locationSelectViewModel.nearestTransports
                                            ForEach(transports) { transport in
                                                transportCardView(transport: transport)
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 15) {
                                    customSectionHeader(title: "最寄りの交通機関", icon: "train.side.front.car")
                                        .padding(.horizontal, 24)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(alignment: .center, spacing: 15) {
                                            ForEach(0..<3, id: \.self) { _ in
                                                transportSkeltonCardView
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                    }
                                }
                            }
                            
                            // MARK: - Place map
                            if let location = selectedPlace.place?.location {
                                VStack(alignment: .leading, spacing: 15) {
                                    customSectionHeader(title: "エリアマップ", icon: "map.fill")
                                    
                                    if !tapMapView {
                                        GMSDetailMapStaticViewRepresentable(clLocation: .init(latitude: location.latitude ?? .zero,
                                                                                        longitude: location.longitude ?? .zero),
                                                                      zoom: 13.0)
                                        .frame(height: 220)
                                        .matchedGeometryEffect(id: "map", in: namespace)
                                        .mask(
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .matchedGeometryEffect(id: "mask", in: namespace)
                                        )
                                        .background {
                                            RoundedRectangle(cornerRadius: 24)
                                                .fill(Color.secondaryBackgroundColor)
                                                .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 8)
                                        }
                                        .overlay(alignment: .topTrailing) {
                                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.black)
                                                .frame(width: 44, height: 44)
                                                .background(.ultraThinMaterial, in: Circle())
                                                .padding(12)
                                        }
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                                self.tapMapView.toggle()
                                            }
                                        }
                                    } else {
                                        Rectangle()
                                            .frame(height: 220)
                                            .foregroundStyle(.clear)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            // MARK: - Rating and reviews
                            if let rating = selectedPlace.place?.rating, rating > 0 {
                                VStack(alignment: .leading, spacing: 15) {
                                    customSectionHeader(title: "評価とレビュー", icon: "star.bubble.fill")
                                        .padding(.horizontal, 24)
                                    
                                    HStack(alignment: .center, spacing: 12) {
                                        Text(String(format: "%.1f", rating))
                                            .font(.system(size: 44, weight: .bold))
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            ratingStarsView(rating: rating, size: 16)
                                            if let count = selectedPlace.place?.userRatingCount {
                                                Text("\(count)件のレビュー")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(.gray)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    
                                    if let reviews = selectedPlace.place?.reviews, !reviews.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(alignment: .center, spacing: 15) {
                                                ForEach(reviews, id: \.self) { review in
                                                    ReviewCardView(review: review)
                                                        .frame(width: 300)
                                                }
                                            }
                                            .padding(.horizontal, 24)
                                            .padding(.bottom, 10)
                                        }
                                    }
                                }
                            }
                            
                            // MARK: - Opening hours
                            if let openingHours = selectedPlace.place?.currentOpeningHours,
                               let weekDays = openingHours.weekdayDescriptions {
                                VStack(alignment: .leading, spacing: 15) {
                                    customSectionHeader(title: "営業時間", icon: "clock.fill")
                                    
                                    VStack(spacing: 0) {
                                        ForEach(0..<weekDays.count, id: \.self) { idx in
                                            let (_, startTime, endTime) = self.weekDayMatch(weekDays[(idx - 1 + weekDays.count) % weekDays.count])
                                            HStack {
                                                Text(days[idx])
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(daysColor[idx])
                                                    .frame(width: 30, alignment: .leading)
                                                
                                                Spacer()
                                                
                                                if let start = startTime, let end = endTime {
                                                    Text("\(start) — \(end)")
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundStyle(.black.opacity(0.7))
                                                } else if startTime != nil {
                                                    Text(startTime!)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundStyle(.black.opacity(0.7))
                                                } else {
                                                    Text("定休日")
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundStyle(.gray.opacity(0.5))
                                                }
                                            }
                                            .padding(.vertical, 12)
                                            
                                            if idx < weekDays.count - 1 {
                                                Divider().background(Color.gray.opacity(0.1))
                                            }
                                        }
                                    }
                                    .padding(20)
                                    .background(Color.secondaryBackgroundColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            // MARK: - Place link
                            if let webSiteUri = selectedPlace.place?.websiteUri,
                                let url = URL(string: webSiteUri) {
                                VStack(alignment: .leading, spacing: 15) {
                                    customSectionHeader(title: "公式Webサイト", icon: "safari.fill")
                                    
                                    if let metadata = self.linkMetaData {
                                        LPLinkThumbnail(metadata: metadata)
                                            .frame(maxWidth: .infinity)
                                            .background(Color.secondaryBackgroundColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .onAppear {
                                    self.fetchMetadata(url: url)
                                }
                            }
                        }
                    }
                }
                
                Spacer().frame(height: 180)
            }
            .overlay(alignment: .bottom) {
                actionButtonsRow
            }
            .ignoresSafeArea(edges: .vertical)
            
            headersOverlay
            
            // Full Map View Overlay
            if let selectedPlace = self.locationSelectViewModel.selectedPlace,
                let place = selectedPlace.place {
                if tapMapView {
                    LocationMapView(latitude: place.location?.latitude ?? .zero,
                                    longitude: place.location?.longitude ?? .zero,
                                    tapMapView: $tapMapView,
                                    namespace: namespace)
                    .environmentObject(locationSelectViewModel)
                }
            }
        }
        .onAppear {
            Task {
                await self.locationSelectViewModel.updatePlaceDetail()
            }
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private var headersOverlay: some View {
        HStack {
            Button(action: {
                if rootViewModel.roots.count > 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        rootViewModel.pop(1)
                    }
                } else {
                    withAnimation {
                        self.isShowScreen.toggle()
                    }
                }
            }) {
                Circle()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.ultraThinMaterial)
                    .overlay {
                        Image(systemName: rootViewModel.roots.count > 1 ? "chevron.left" : "chevron.down")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
            .padding(.leading, 20)
            .padding(.top, 20)
            Spacer()
        }
        .background {
            LinearGradient(
                colors: [.black.opacity(0.5), .black.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    private var actionButtonsRow: some View {
        HStack(spacing: 20) {
            if viewMode == .notCandidate {
                Button(action: {
                    self.locationSelectViewModel.addPlace()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.isShowScreen.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "tray.and.arrow.down.fill")
                        Text("候補に追加")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.subFontColor)
                    .clipShape(Capsule())
                    .shadow(color: Color.subFontColor.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                
                Button(action: {
                    self.locationSelectViewModel.addPlace()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.rootViewModel.push(.editor)
                    }
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("投稿")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.mainColor)
                    .clipShape(Capsule())
                    .shadow(color: Color.mainColor.opacity(0.3), radius: 10, x: 0, y: 5)
                }
            } else {
                Button(action: {
                    self.locationSelectViewModel.removePlace()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.isShowScreen.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("候補から外す")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.subFontColor)
                    .clipShape(Capsule())
                    .shadow(color: Color.subFontColor.opacity(0.3), radius: 10, x: 0, y: 5)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    @ViewBuilder
    private func customSectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.mainColor)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
        }
    }
    
    @ViewBuilder
    private func ratingStarsView(rating: Double, size: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Image(systemName: index < Int(rating) ? "star.fill" : (index < Int(rating.rounded()) ? "star.leadinghalf.filled" : "star"))
                    .font(.system(size: size))
                    .foregroundStyle(.orange)
            }
        }
    }
    
    @ViewBuilder
    private func transportCardView(transport: GooglePlacesTransport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                let (imageName, _) = self.placeTypeImage(placeTypes: transport.place.types ?? [])
                if !imageName.isEmpty {
                    Image(systemName: imageName == "Railway Car" ? "tram.fill" : (imageName == "Bus" ? "bus.fill" : "ship.fill"))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mainColor)
                }
                
                Text(transport.place.displayName?.text ?? "駅名なし")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .lineLimit(1)
            }
            
            HStack(spacing: 4) {
                Text("現在地から")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.gray)
                Text(distanceFormat(transport.l2Distance))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.selectedColor)
            }
        }
        .padding(15)
        .frame(width: 220, height: 100)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    @ViewBuilder
    private var transportSkeltonCardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Circle()
                .frame(width: 24, height: 24)
                .foregroundStyle(.gray.opacity(0.1))
                .skelton(isActive: true)
            
            Rectangle()
                .frame(height: 16)
                .foregroundStyle(.gray.opacity(0.1))
                .skelton(isActive: true)
            
            Rectangle()
                .frame(width: 100, height: 12)
                .foregroundStyle(.gray.opacity(0.1))
                .skelton(isActive: true)
        }
        .padding(15)
        .frame(width: 220, height: 100)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    
    private func distanceFormat(_ distance: Double) -> String {
        if distance >= 1000 {
            let normDis = round((distance / 1000.0) * 10.0) / 10.0
            return normDis.description + "km"
        }
        let normDis = round(distance * 10.0) / 10.0
        return Int(normDis).description + "m"
    }
    
    private func placeTypeImage(placeTypes: [String]) -> (String, String) {
        guard let firstPlaceType = placeTypes.first else { return ("", "") }
        if firstPlaceType == "train_station" { return ("Railway Car", "電車") }
        if firstPlaceType == "subway_station" { return ("Railway Car", "地下鉄") }
        if firstPlaceType == "ferry_terminal" { return ("Passenger Ship", "船乗り場") }
        if firstPlaceType == "bus_station" { return ("Bus", "バス乗り場") }
        return ("", "")
    }
    
    private func fetchMetadata(url: URL) {
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { meta, error in
            if let error = error {
                print("Failed to fetch metadata. \(error.localizedDescription)")
                return
            }
            DispatchQueue.main.async {
                self.linkMetaData = meta
            }
        }
    }
    
    private func weekDayMatch(_ day: String) -> (String?, String?, String?) {
        if let match = day.firstMatch(of: /(.+曜日): (.+)/) {
            let day = String(match.1)
            let businessHours = match.2
            let timePattern = /\d{1,2}時\d{2}分/
            let times = businessHours.matches(of: timePattern).map({ String($0.output) })
            
            if times.count == 2 {
                return (day.first?.description, timeFormat(time: times[0]), timeFormat(time: times[1]))
            }
            if times.count == 1 {
                return (day.first?.description, timeFormat(time: times[0]), nil)
            }
            return (day.first?.description, nil, nil)
        }
        return (nil, nil, nil)
    }
    
    private func timeFormat(time: String) -> String {
        let digits = time.matches(of: /\d+/).map { String($0.output) }
        if digits.count == 2 {
            return "\(digits[0]):\(digits[1])"
        }
        return time
    }
}

// MARK: - Location Review Card
//fileprivate struct ReviewCardView: View {
//    let review: GooglePlacesSearchResponseReview
//    @State private var isPopover: Bool = false
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 15) {
//            HStack(alignment: .center, spacing: 12) {
//                WebImage(url: URL(string: review.authorAttribution?.photoUri ?? "")) { image in
//                    image.resizable().scaledToFill()
//                } placeholder: {
//                    Circle().fill(Color.gray.opacity(0.1))
//                }
//                .frame(width: 42, height: 42)
//                .clipShape(Circle())
//                
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(review.authorAttribution?.displayName ?? "匿名ユーザー")
//                        .font(.system(size: 14, weight: .bold))
//                        .foregroundStyle(.black.opacity(0.8))
//                    
//                    if let rating = review.rating {
//                        HStack(spacing: 2) {
//                            ForEach(0..<5) { index in
//                                Image(systemName: "star.fill")
//                                    .font(.system(size: 10))
//                                    .foregroundStyle(index < rating ? .orange : .gray.opacity(0.2))
//                            }
//                        }
//                    }
//                }
//                Spacer()
//            }
//            
//            Text(review.text?.text ?? "")
//                .font(.system(size: 13, weight: .medium))
//                .foregroundStyle(.black.opacity(0.7))
//                .lineLimit(4)
//                .multilineTextAlignment(.leading)
//                .lineSpacing(4)
//        }
//        .padding(18)
//        .frame(height: 180)
//        .background(Color.secondaryBackgroundColor)
//        .clipShape(RoundedRectangle(cornerRadius: 22))
//        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
//        .onTapGesture {
//            withAnimation(.spring()) {
//                self.isPopover.toggle()
//            }
//        }
//        .popup(isPresented: $isPopover) {
//            VStack(alignment: .leading, spacing: 20) {
//                HStack(spacing: 15) {
//                    WebImage(url: URL(string: review.authorAttribution?.photoUri ?? "")) { image in
//                        image.resizable().scaledToFill()
//                    } placeholder: {
//                        Circle().fill(Color.gray.opacity(0.1))
//                    }
//                    .frame(width: 50, height: 50)
//                    .clipShape(Circle())
//                    
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text(review.authorAttribution?.displayName ?? "匿名ユーザー")
//                            .font(.system(size: 16, weight: .bold))
//                        
//                        if let rating = review.rating {
//                            HStack(spacing: 2) {
//                                ForEach(0..<5) { index in
//                                    Image(systemName: "star.fill")
//                                        .font(.system(size: 12))
//                                        .foregroundStyle(index < rating ? .orange : .gray.opacity(0.2))
//                                }
//                            }
//                        }
//                    }
//                }
//                
//                ScrollView {
//                    Text(review.text?.text ?? "")
//                        .font(.system(size: 15, weight: .medium))
//                        .foregroundStyle(.black.opacity(0.8))
//                        .lineSpacing(6)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                }
//            }
//            .padding(25)
//            .background(Color.backgroundColor)
//            .clipShape(RoundedRectangle(cornerRadius: 30))
//            .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
//            .padding(.horizontal, 24)
//        } customize: { item in
//            item
//                .type(.floater())
//                .animation(.spring())
//                .closeOnTap(true)
//                .closeOnTapOutside(true)
//                .position(.center)
//                .appearFrom(.centerScale)
//                .backgroundColor(Color.black.opacity(0.4))
//        }
//    }
//}

// MARK: - Location Detail Map
fileprivate struct LocationMapView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    let latitude: Double
    let longitude: Double
    
    @Binding var tapMapView: Bool
    var namespace: Namespace.ID
    
    @State private var isSearch: Bool = false
    @State private var query: String = ""
    @FocusState private var focus: Bool
    
    var body: some View {
        ZStack {
            GMSDetailMapViewRepresentable(clLocation: .init(latitude: latitude, longitude: longitude), zoom: 13)
                .ignoresSafeArea()
                .zIndex(1)
            
            if isSearch {
                Color.backgroundColor.ignoresSafeArea(.keyboard, edges: .all)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .move(edge: .bottom)))
                    .zIndex(2)
            }
            
            if focus {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea(.keyboard, edges: .all)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            focus.toggle()
                        }
                    }
                    .zIndex(3)
            }
            
            VStack(alignment: .center) {
                HStack(alignment: .center, spacing: 15) {
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            if !isSearch {
                                // Reset all property of related to nearest text search.
                                self.locationSelectViewModel.nearestLocations.removeAll()
                                self.locationSelectViewModel.textSearchResults.removeAll()
                                tapMapView.toggle()
                            } else {
                                // Reset search result and query.
                                self.locationSelectViewModel.textSearchResults.removeAll()
                                query.removeAll()
                                
                                isSearch.toggle()
                                focus = false
                            }
                            
                            self.locationSelectViewModel.selectedNearestWrapper = nil
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 40, height: 40)
                            .foregroundStyle(.gray)
                            .padding(10)
                            .background {
                                Circle()
                                    .frame(width: 50, height: 50)
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                                    .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    
                    if isSearch {
                        TextField("近隣を検索", text: $query)
                            .focused($focus)
                            .padding(15)
                            .background {
                                RoundedRectangle(cornerRadius: 20)
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                                    .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
                            }
                            .matchedGeometryEffect(id: "search", in: namespace)
                            .onSubmit {
                                Task {
                                    await self.locationSelectViewModel.textNearbySearch(query)
                                }
                            }
                    } else {
                        Group {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isSearch.toggle()
                                    self.locationSelectViewModel.selectedNearestWrapper = nil
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    focus = true
                                }
                            }) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(Color.white)
                                    .padding(10)
                                    .background {
                                        Circle()
                                            .frame(width: 50, height: 50)
                                            .foregroundStyle(Color.mainColor)
                                            .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                                            .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                        .matchedGeometryEffect(id: "search", in: namespace)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                let textSearchResults = locationSelectViewModel.textSearchResults
                if isSearch && !textSearchResults.isEmpty {
                    VStack(alignment: .leading) {
                        ScrollView(.vertical) {
                            VStack(alignment: .leading) {
                                ForEach(textSearchResults) { wrapper in
                                    if let place = wrapper.place {
                                        Button(action: {
                                            self.locationSelectViewModel.addNearbyTextPlace(wrapper: wrapper)
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                isSearch = false
                                                focus = false
                                            }
                                        }) {
                                            HStack(alignment: .center) {
                                                VStack(alignment: .leading) {
                                                    Text(place.displayName?.text ?? "Unkown name")
                                                        .font(.system(size: 15, weight: .bold))
                                                        .foregroundStyle(.black.opacity(0.8))
                                                    Text(place.formattedAddress ?? "")
                                                        .font(.caption)
                                                        .foregroundStyle(.gray)
                                                }
                                                .padding([.top, .horizontal], 10)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            Spacer()
                                .frame(height: 100)
                        }
                        .scrollIndicators(.hidden)
                    }
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
                    .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
                    .padding([self.isSearch ? .horizontal : .horizontal, .top], 20)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .zIndex(4)
            
        }
        .matchedGeometryEffect(id: "map", in: namespace)
        .mask(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .matchedGeometryEffect(id: "mask", in: namespace)
        )
        .ignoresSafeArea()
        .popup(item: $locationSelectViewModel.selectedNearestWrapper) { wrapper in
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let photo = wrapper.place.photos?.first {
                        WebImage(url: photo.buildUrl()) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .foregroundStyle(.gray.opacity(0.8))
                                .skelton(isActive: true)
                        }
                    } else {
                        Image("NoPlaceImage")
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(height: 180)
                .clipped()

                VStack(alignment: .leading, spacing: 8) {
                    Text(wrapper.place.displayName?.text ?? "")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black.opacity(0.8))
                    
                    Text(wrapper.place.formattedAddress ?? "")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    HStack(alignment: .center, spacing: .zero) {
                        Text("目的地までの距離 ")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(distanceFormat(wrapper.l2Distance))
                            .font(.caption)
                            .foregroundStyle(.black)
                        Spacer()
                    }
                }
                .padding(20)
            }
            .frame(width: UIScreen.main.bounds.width - 40)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
            .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
        } customize: { view in
            view
                .type(.floater())
                .position(.bottom)
                .appearFrom(.centerScale)
                .animation(.spring())
                .closeOnTap(false)
                .closeOnTapOutside(true)
                .useKeyboardSafeArea(false)
        }
        
    }
    
    private func distanceFormat(_ distance: Double) -> String {
        if distance >= 1000 {
            let normDis = round((distance / 1000.0) * 10.0) / 10.0
            return normDis.description + "km"
        }
        
        let normDis = round(distance * 10.0) / 10.0
        return normDis.description + "m"
    }
}
