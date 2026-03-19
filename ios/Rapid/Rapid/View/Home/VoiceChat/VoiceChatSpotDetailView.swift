//
//  VoiceChatSpotDetailView.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/16.
//

import SwiftUI
import SDWebImageSwiftUI
import PopupView
import LinkPresentation
import CoreLocation

struct VoiceChatSpotDetailView: View {
    @EnvironmentObject private var viewModel: VoiceChatViewModel
    @Binding var isShowScreen: Bool
    
    @State private var scrollIdx: Int? = 0
    @State private var linkMetaData: LPLinkMetadata? = nil
    
    private let days: [String] = ["日", "月", "火", "水", "木", "金", "土"]
    private let daysColor: [Color] = [.blue, .black, .black, .black, .black, .black, .red]
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.backgroundColor.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: .zero) {
                    // MARK: - Place photos
                    if let selectedPlace = viewModel.detailViewingPlace {
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
                            if !viewModel.nearestTransports.isEmpty {
                                VStack(alignment: .leading, spacing: 15) {
                                    customSectionHeader(title: "最寄りの交通機関", icon: "train.side.front.car")
                                        .padding(.horizontal, 24)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(alignment: .center, spacing: 15) {
                                            let transports = viewModel.nearestTransports
                                            ForEach(transports) { transport in
                                                transportCardView(transport: transport)
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                    }
                                }
                            } else if viewModel.isLoadingNearestTransports {
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
                                    
                                    GMSDetailMapStaticViewRepresentable(
                                        clLocation: .init(latitude: location.latitude ?? .zero, longitude: location.longitude ?? .zero),
                                        zoom: 13.0
                                    )
                                    .frame(height: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .background {
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(Color.secondaryBackgroundColor)
                                            .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 8)
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
        }
        .onAppear {
            Task {
                await viewModel.updatePlaceDetail()
            }
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private var headersOverlay: some View {
        HStack {
            Button(action: {
                withAnimation {
                    self.isShowScreen.toggle()
                }
            }) {
                Circle()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.ultraThinMaterial)
                    .overlay {
                        Image(systemName: "chevron.down")
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
        if viewModel.joinedEventUser == nil {
            Button(action: {
                viewModel.selectedVotingPlace = viewModel.detailViewingPlace
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.isShowScreen.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("このスポットに決定")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.thirdColor)
                .clipShape(Capsule())
                .shadow(color: Color.thirdColor.opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
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
                Text("スポットから")
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
