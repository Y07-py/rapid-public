//
//  RecruitmentLocationComponents.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/05.
//

import SwiftUI
import SDWebImageSwiftUI
import PopupView
import LinkPresentation
import CoreLocation

public struct RecruitmentLocationView: View {
    @EnvironmentObject private var recruitmentViewModel: RecruitmentViewModel
    
    // Allow passing a recruitment directly for reuse in Activity tab
    public var recruitment: RecruitmentWithUserProfile? = nil
    
    @State private var selectedPlace: GooglePlacesSearchPlaceWrapper? = nil
    
    public init(recruitment: RecruitmentWithUserProfile? = nil) {
        self.recruitment = recruitment
    }
    
    public var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: .zero) {
                if let recruitment = recruitment ?? recruitmentViewModel.selectedRecruitment {
                    let places = recruitment.places
                    
                    if places.count == 1 {
                        ScrollView(.vertical) {
                            RecruitmentLocationDetailView(wrapper: places.first!)
                                .environmentObject(recruitmentViewModel)
                            Spacer().frame(height: 150)
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            // Carousel for multiple locations
                            ScrollView(.horizontal) {
                                HStack(spacing: 16) {
                                    ForEach(places) { wrapper in
                                        locationCarouselItem(wrapper: wrapper, currentRecruitment: recruitment)
                                            .onTapGesture {
                                                withAnimation(.spring()) {
                                                    self.selectedPlace = wrapper
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 120) // Give space for the header
                                .padding(.bottom, 20)
                            }
                            .scrollIndicators(.hidden)
                            
                            Divider()
                                .padding(.horizontal, 20)
                            
                            // Detail view for the selected location from carousel
                            ScrollView(.vertical) {
                                if let selected = selectedPlace ?? places.first {
                                    RecruitmentLocationDetailView(wrapper: selected)
                                        .environmentObject(recruitmentViewModel)
                                        .id(selected.id) // Ensure view refreshes on selection
                                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                                Spacer().frame(height: 150)
                            }
                            .scrollIndicators(.hidden)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
    
    @ViewBuilder
    private func locationCarouselItem(wrapper: GooglePlacesSearchPlaceWrapper, currentRecruitment: RecruitmentWithUserProfile) -> some View {
        let isSelected = (selectedPlace?.id ?? currentRecruitment.places.first?.id) == wrapper.id
        
        VStack(alignment: .leading, spacing: 8) {
            if let photo = wrapper.place?.photos?.first {
                WebImage(url: photo.buildUrl()) { view in
                    view.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().foregroundStyle(.gray.opacity(0.1)).skelton(isActive: true)
                }
                .frame(width: 120, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image("NoPlaceImage")
                    .resizable().scaledToFill()
                    .frame(width: 120, height: 80)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Text(wrapper.place?.displayName?.text ?? "No Name")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isSelected ? .black : .gray)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
        }
        .padding(8)
        .background(isSelected ? Color.thirdColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.thirdColor : Color.clear, lineWidth: 2)
        )
    }
}

public struct RecruitmentLocationDetailView: View {
    @EnvironmentObject private var recruitmentViewModel: RecruitmentViewModel
    let wrapper: GooglePlacesSearchPlaceWrapper
    
    @State private var scrollIdx: Int? = 0
    @State private var linkMetaData: LPLinkMetadata? = nil
    
    private let days: [String] = ["日", "月", "火", "水", "木", "金", "土"]
    private let daysColor: [Color] = [.blue, .black, .black, .black, .black, .black, .red]
    
    public init(wrapper: GooglePlacesSearchPlaceWrapper) {
        self.wrapper = wrapper
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            let photos = wrapper.place?.photos ?? []
            
            // MARK: - Photo Gallery
            ZStack(alignment: .bottom) {
                ScrollView(.horizontal) {
                    HStack(alignment: .center, spacing: .zero) {
                        if photos.isEmpty {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .containerRelativeFrame(.horizontal)
                                .frame(height: 520)
                                .overlay {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.gray.opacity(0.3))
                                }
                        } else {
                            ForEach(0..<min(5, photos.count), id: \.self) { idx in
                                let photo = photos[idx]
                                WebImage(url: photo.buildUrl()) { view in
                                    view
                                        .resizable()
                                        .scaledToFill()
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
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                
                if photos.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<min(5, photos.count), id: \.self) { idx in
                            Capsule()
                                .frame(width: idx == scrollIdx ? 20 : 6, height: 6)
                                .foregroundStyle(idx == scrollIdx ? .white : .white.opacity(0.4))
                                .animation(.spring(response: 0.3), value: scrollIdx)
                        }
                    }
                    .padding(.bottom, 25)
                }
            }
            .ignoresSafeArea(edges: .top)
            
            VStack(alignment: .leading, spacing: 32) {
                // MARK: - Place Name & Address
                VStack(alignment: .leading, spacing: 12) {
                    Text(wrapper.place?.displayName?.text ?? "不明なスポット")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                    
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.selectedColor)
                        
                        Text(wrapper.place?.formattedAddress ?? "住所情報なし")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.gray)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 25)
                
                // MARK: - Nearest transports
                if recruitmentViewModel.isLoadingNearestTransports || !recruitmentViewModel.nearestTransports.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        customSectionHeader(title: "最寄りの交通機関", icon: "train.side.front.car")
                            .padding(.horizontal, 24)
                        
                        ScrollView(.horizontal) {
                            HStack(alignment: .center, spacing: 15) {
                                if recruitmentViewModel.isLoadingNearestTransports {
                                    ForEach(0..<3, id: \.self) { _ in
                                        transportSkeltonCardView
                                    }
                                } else {
                                    ForEach(recruitmentViewModel.nearestTransports) { transport in
                                        transportCardView(transport: transport)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
                
                // MARK: - Place map
                if let location = wrapper.place?.location {
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
                if let rating = wrapper.place?.rating, rating > 0 {
                    VStack(alignment: .leading, spacing: 15) {
                        customSectionHeader(title: "評価とレビュー", icon: "star.bubble.fill")
                            .padding(.horizontal, 24)
                        
                        HStack(alignment: .center, spacing: 12) {
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 44, weight: .bold))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                ratingStarsView(rating: rating, size: 16)
                                if let count = wrapper.place?.userRatingCount {
                                    Text("\(count)件のレビュー")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.gray)
                                } else if recruitmentViewModel.isLoadingDetail {
                                    Rectangle()
                                        .frame(width: 80, height: 12)
                                        .foregroundStyle(.gray.opacity(0.1))
                                        .skelton(isActive: true)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        if let reviews = wrapper.place?.reviews, !reviews.isEmpty {
                            ScrollView(.horizontal) {
                                HStack(alignment: .center, spacing: 15) {
                                    ForEach(reviews, id: \.self) { review in
                                        ReviewCardView(review: review)
                                            .frame(width: 300)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 10)
                            }
                            .scrollIndicators(.hidden)
                        } else if recruitmentViewModel.isLoadingDetail {
                            ScrollView(.horizontal) {
                                HStack(alignment: .center, spacing: 15) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        reviewSkeltonCardView
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                            .scrollIndicators(.hidden)
                        }
                    }
                }
                
                // MARK: - Opening hours
                if recruitmentViewModel.isLoadingDetail || (wrapper.place?.currentOpeningHours != nil) {
                    VStack(alignment: .leading, spacing: 15) {
                        customSectionHeader(title: "営業時間", icon: "clock.fill")
                        
                        if let openingHours = wrapper.place?.currentOpeningHours,
                           let weekDays = openingHours.weekdayDescriptions {
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
                        } else {
                            openingHoursSkeltonView
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                // MARK: - Place link
                if let webSiteUri = wrapper.place?.websiteUri,
                   let url = URL(string: webSiteUri) {
                    VStack(alignment: .leading, spacing: 15) {
                        customSectionHeader(title: "公式Webサイト", icon: "safari.fill")
                        
                        if let metadata = self.linkMetaData {
                            LPLinkThumbnail(metadata: metadata)
                                .frame(maxWidth: .infinity)
                                .background(Color.secondaryBackgroundColor)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
                        } else {
                            Text(webSiteUri)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.selectedColor)
                                .underline()
                        }
                    }
                    .padding(.horizontal, 24)
                    .onAppear {
                        self.fetchMetadata(url: url)
                    }
                }
                
                Spacer().frame(height: 180)
            }
        }
        .onAppear {
            Task {
                await recruitmentViewModel.updateNearestTransport(wrapper: wrapper)
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
        .frame(width: 220)
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
        .frame(width: 220)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    
    @ViewBuilder
    private var reviewSkeltonCardView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Circle()
                    .frame(width: 42, height: 42)
                    .foregroundStyle(.gray.opacity(0.1))
                    .skelton(isActive: true)
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle()
                        .frame(width: 100, height: 14)
                        .foregroundStyle(.gray.opacity(0.1))
                        .skelton(isActive: true)
                    Rectangle()
                        .frame(width: 60, height: 10)
                        .foregroundStyle(.gray.opacity(0.1))
                        .skelton(isActive: true)
                }
            }
            Rectangle()
                .frame(height: 60)
                .foregroundStyle(.gray.opacity(0.1))
                .skelton(isActive: true)
        }
        .padding(18)
        .frame(width: 300, height: 180)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
    
    @ViewBuilder
    private var openingHoursSkeltonView: some View {
        VStack(spacing: 12) {
            ForEach(0..<7, id: \.self) { _ in
                Rectangle()
                    .frame(height: 20)
                    .foregroundStyle(.gray.opacity(0.1))
                    .skelton(isActive: true)
            }
        }
        .padding(20)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 24))
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
public struct ReviewCardView: View {
    let review: GooglePlacesSearchResponseReview
    @State private var isPopover: Bool = false
    
    public init(review: GooglePlacesSearchResponseReview) {
        self.review = review
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 12) {
                WebImage(url: URL(string: review.authorAttribution?.photoUri ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.1))
                }
                .frame(width: 42, height: 42)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.authorAttribution?.displayName ?? "匿名ユーザー")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                    
                    if let rating = review.rating {
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(index < rating ? .orange : .gray.opacity(0.2))
                            }
                        }
                    }
                }
                Spacer()
            }
            
            Text(review.text?.text ?? "")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.black.opacity(0.7))
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
        }
        .padding(18)
        .frame(height: 180)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
        .onTapGesture {
            withAnimation(.spring()) {
                self.isPopover.toggle()
            }
        }
        .popup(isPresented: $isPopover) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 15) {
                    WebImage(url: URL(string: review.authorAttribution?.photoUri ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.1))
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(review.authorAttribution?.displayName ?? "匿名ユーザー")
                            .font(.system(size: 16, weight: .bold))
                        
                        if let rating = review.rating {
                            HStack(spacing: 2) {
                                ForEach(0..<5) { index in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(index < rating ? .orange : .gray.opacity(0.2))
                                }
                            }
                        }
                    }
                }
                
                ScrollView {
                    Text(review.text?.text ?? "")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black.opacity(0.8))
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(25)
            .background(Color.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 24)
        } customize: { item in
            item
                .type(.floater())
                .animation(.spring())
                .closeOnTap(true)
                .closeOnTapOutside(true)
                .position(.center)
                .appearFrom(.centerScale)
                .backgroundColor(Color.black.opacity(0.4))
        }
    }
}

// MARK: - Shared UI Components
extension View {
    @ViewBuilder
    public func customSectionHeader(title: String, icon: String) -> some View {
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
    public func ratingStarsView(rating: Double, size: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Image(systemName: index < Int(rating) ? "star.fill" : (index < Int(rating.rounded()) ? "star.leadinghalf.filled" : "star"))
                    .font(.system(size: size))
                    .foregroundStyle(.orange)
            }
        }
    }
}
