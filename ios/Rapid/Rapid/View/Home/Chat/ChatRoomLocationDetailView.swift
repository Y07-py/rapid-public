//
//  ChatRoomLocationDetailView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/08.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import PopupView
import LinkPresentation

struct ChatRoomLocationDetailView: View {
    @EnvironmentObject private var chatRoomViewModel: ChatRoomViewModel
    @EnvironmentObject private var rootViewModel: RootViewModel<LocationListRoot>
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedPlace: GooglePlacesSearchPlaceWrapper?
    let viewType: ChatRoomLocationViewType

    @State private var scrollIdx: Int? = nil
    @State private var linkMetaData: LPLinkMetadata? = nil
    @State private var nearestTransports: [GooglePlacesTransport] = []
    @State private var detailLoaded: Bool = false
    @State private var detailedPlace: GooglePlacesSearchResponsePlace? = nil

    private let days: [String] = ["日", "月", "火", "水", "木", "金", "土"]
    private let daysColor: [Color] = [.blue, .black, .black, .black, .black, .black, .red]

    var body: some View {
        ZStack(alignment: .top) {
            Color.backgroundColor.ignoresSafeArea()
            ScrollView(.vertical) {
                VStack(spacing: .zero) {
                    if let place = selectedPlace {
                        let effectiveWrapper = detailedPlace != nil ? GooglePlacesSearchPlaceWrapper(place: detailedPlace!) : place
                        let effectivePlace = effectiveWrapper.place
                        
                        // MARK: - Place photos
                        photoCarouselView(place: effectiveWrapper)

                        // MARK: - Place name & address
                        placeHeaderView(place: effectiveWrapper)

                        // MARK: - Nearest transports
                        nearestTransportsSection

                        // MARK: - Area map
                        if let location = effectivePlace?.location {
                            mapSection(location: location)
                        }

                        // MARK: - Rating & reviews
                        reviewsSection(rating: effectivePlace?.rating, reviews: effectivePlace?.reviews)

                        // MARK: - Opening hours
                        if let openingHours = effectivePlace?.currentOpeningHours,
                           let weekDays = openingHours.weekdayDescriptions {
                            openingHoursSection(weekDays: weekDays)
                        }

                        // MARK: - Official website
                        if let webSiteUri = effectivePlace?.websiteUri,
                           let url = URL(string: webSiteUri) {
                            websiteSection(url: url)
                        }
                    }
                }

                Spacer()
                    .frame(height: 100)
            }
            .ignoresSafeArea(edges: .top)

            // MARK: - Top gradient & back button
            LinearGradient(
                gradient: Gradient(colors: [.black.opacity(0.5), .clear]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .ignoresSafeArea()

            HStack {
                Button(action: {
                    if viewType == .list {
                        self.rootViewModel.pop(1)
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: viewType == .list ? "chevron.left" : "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.leading, 20)
                .padding(.top, 20)
                Spacer()
            }
        }
        .onAppear {
            guard !detailLoaded else { return }
            Task {
                await loadPlaceDetail()
                detailLoaded = true
            }
        }
    }

    // MARK: - Data loading

    private func loadPlaceDetail() async {
        guard let wrapper = selectedPlace else { return }

        if let detail = await chatRoomViewModel.fetchPlaceDetail(wrapper, fieldMask: GooglePlaceFieldMask.detailFieldMask) {
            await MainActor.run {
                self.detailedPlace = detail.place
            }
        }

        if let lat = wrapper.place?.location?.latitude,
           let lon = wrapper.place?.location?.longitude {
            let transports = await chatRoomViewModel.searchNearbyTransports(latitude: lat, longitude: lon)
            await MainActor.run {
                self.nearestTransports = transports
            }
        }
    }
}

// MARK: - Photo carousel
extension ChatRoomLocationDetailView {
    @ViewBuilder
    private func photoCarouselView(place: GooglePlacesSearchPlaceWrapper) -> some View {
        let photos = place.place?.photos ?? []
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
    }
}

// MARK: - Place header
extension ChatRoomLocationDetailView {
    @ViewBuilder
    private func placeHeaderView(place: GooglePlacesSearchPlaceWrapper) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(place.place?.displayName?.text ?? "不明なスポット")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black.opacity(0.85))
            
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.selectedColor)
                
                Text(place.place?.formattedAddress ?? "住所情報なし")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.gray)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 25)
    }
}

// MARK: - Nearest transports
extension ChatRoomLocationDetailView {
    @ViewBuilder
    private var nearestTransportsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            customSectionHeader(title: "最寄りの交通機関", icon: "train.side.front.car")
                .padding(.horizontal, 24)

            ScrollView(.horizontal) {
                HStack(alignment: .center, spacing: 15) {
                    if nearestTransports.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in
                            transportSkeltonCardView
                        }
                    } else {
                        ForEach(nearestTransports) { transport in
                            transportCardView(transport: transport)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 30)
    }

    @ViewBuilder
    private func transportCardView(transport: GooglePlacesTransport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text(transport.place.displayName?.text ?? "")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.black.opacity(0.8))
                Spacer()
            }
            .padding([.top, .horizontal], 10)

            HStack(alignment: .center, spacing: 5) {
                Text("目的地まで")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.gray.opacity(0.8))
                Text(distanceFormat(transport.l2Distance))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black.opacity(0.8))
                Spacer()
            }
            .padding(.horizontal, 10)

            HStack(alignment: .center, spacing: 5) {
                Spacer()
                let (imageName, typeName) = placeTypeImage(placeTypes: transport.place.types ?? [])
                if !imageName.isEmpty {
                    Image(systemName: imageName)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mainColor)
                    Text(typeName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.gray.opacity(0.8))
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(width: 200, height: 110)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    private var transportSkeltonCardView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Rectangle()
                    .frame(width: 120, height: 20)
                    .foregroundStyle(.gray.opacity(0.8))
                    .skelton(isActive: true)
                Spacer()
            }
            .padding([.top, .horizontal], 10)

            HStack(alignment: .center) {
                Rectangle()
                    .frame(width: 80, height: 15)
                    .foregroundStyle(.gray.opacity(0.8))
                    .skelton(isActive: true)
                Spacer()
            }
            .padding(.horizontal, 10)

            HStack(alignment: .center) {
                Spacer()
                Rectangle()
                    .frame(width: 60, height: 15)
                    .foregroundStyle(.gray.opacity(0.8))
                    .skelton(isActive: true)
            }
            .padding(.horizontal, 10)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .frame(width: 200, height: 110)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Map
extension ChatRoomLocationDetailView {
    @ViewBuilder
    private func mapSection(location: GooglePlacesSearchResponseLatLng) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            customSectionHeader(title: "エリアマップ", icon: "map.fill")
            
            GMSDetailMapStaticViewRepresentable(
                clLocation: .init(
                    latitude: location.latitude ?? .zero,
                    longitude: location.longitude ?? .zero
                ),
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
        .padding(.top, 30)
        .padding(.horizontal, 24)
    }
}

// MARK: - Reviews
extension ChatRoomLocationDetailView {
    @ViewBuilder
    private func reviewsSection(rating: Double?, reviews: [GooglePlacesSearchResponseReview]?) -> some View {
        if let rating = rating, rating > 0 {
            VStack(alignment: .leading, spacing: 15) {
                customSectionHeader(title: "評価とレビュー", icon: "star.bubble.fill")
                    .padding(.horizontal, 24)
                
                HStack(alignment: .center, spacing: 12) {
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 44, weight: .bold))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ratingTextView(rating: rating, textSize: 16, starSize: 16, mean: false)
                        if let count = detailedPlace?.userRatingCount ?? selectedPlace?.place?.userRatingCount {
                            Text("\(count)件のレビュー")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.gray)
                        } else if !detailLoaded {
                            Rectangle()
                                .frame(width: 80, height: 12)
                                .foregroundStyle(.gray.opacity(0.1))
                                .skelton(isActive: true)
                        }
                    }
                }
                .padding(.horizontal, 24)

                if let reviews = reviews, !reviews.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(alignment: .center, spacing: 15) {
                            ForEach(reviews, id: \.self) { review in
                                ChatRoomReviewCardView(review: review)
                                    .frame(width: 300)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 10)
                    }
                    .scrollIndicators(.hidden)
                } else if !detailLoaded {
                    ScrollView(.horizontal) {
                        HStack(alignment: .center, spacing: 15) {
                            ForEach(0..<3, id: \.self) { _ in
                                reviewCardSkeltonView
                                    .frame(width: 300)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.top, 30)
        }
    }

    @ViewBuilder
    private func ratingTextView(rating: Double, textSize: CGFloat, starSize: CGFloat, mean: Bool = false) -> some View {
        let integer = Int(rating)
        let fraction = Int(round(rating.truncatingRemainder(dividingBy: 1)))
        let nonStars = 5 - integer - fraction
        HStack {
            HStack(alignment: .center) {
                ForEach(0..<integer, id: \.self) { _ in
                    Image("Star")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: starSize, height: starSize)
                }
                ForEach(0..<fraction, id: \.self) { _ in
                    Image("HalfStar")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: starSize, height: starSize)
                }
                ForEach(0..<nonStars, id: \.self) { _ in
                    Image("NonStar")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: starSize, height: starSize)
                }
            }
        }
    }

    @ViewBuilder
    private var reviewCardSkeltonView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.gray.opacity(0.8))
                    .skelton(isActive: true)
                Rectangle()
                    .frame(width: 150, height: 15)
                    .foregroundStyle(.gray.opacity(0.8))
                    .skelton(isActive: true)
            }
            HStack(alignment: .center, spacing: 10) {
                Rectangle()
                    .frame(width: 100, height: 10)
                    .foregroundStyle(.gray.opacity(0.8))
                    .skelton(isActive: true)
                Rectangle()
                    .frame(width: 80, height: 10)
                    .foregroundStyle(.gray.opacity(0.8))
                    .skelton(isActive: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .frame(maxWidth: .infinity)
                        .frame(height: 12)
                        .foregroundStyle(.gray.opacity(0.8))
                        .skelton(isActive: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: 200)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
        }
        .padding(.horizontal, 5)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
        .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
    }
}

// MARK: - Opening hours
extension ChatRoomLocationDetailView {
    @ViewBuilder
    private func openingHoursSection(weekDays: [String]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            customSectionHeader(title: "営業時間", icon: "clock.fill")
                .padding(.horizontal, 24)
            
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
            .padding(.horizontal, 24)
        }
        .padding(.top, 30)
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

// MARK: - Website link
extension ChatRoomLocationDetailView {
    @ViewBuilder
    private func websiteSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            customSectionHeader(title: "公式Webサイト", icon: "safari.fill")
                .padding(.horizontal, 24)
            
            if let metadata = self.linkMetaData {
                LPLinkThumbnail(metadata: metadata)
                    .frame(maxWidth: .infinity)
                    .background(Color.secondaryBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 24)
            } else {
                Text(url.absoluteString)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.selectedColor)
                    .underline()
                    .padding(.horizontal, 24)
            }
        }
        .padding(.top, 30)
        .onAppear {
            self.fetchMetadata(url: url)
        }
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
}

// MARK: - Helpers
extension ChatRoomLocationDetailView {
    private func distanceFormat(_ distance: Double) -> String {
        if distance >= 1000 {
            let normDis = round((distance / 1000.0) * 10.0) / 10.0
            return normDis.description + "km"
        }
        let normDis = round(distance * 10.0) / 10.0
        return normDis.description + "m"
    }

    private func placeTypeImage(placeTypes: [String]) -> (String, String) {
        guard let firstPlaceType = placeTypes.first else { return ("", "") }

        if firstPlaceType == "train_station" {
            return ("tram.fill", "電車")
        } else if firstPlaceType == "subway_station" {
            return ("tram.fill", "地下鉄")
        } else if firstPlaceType == "ferry_terminal" {
            return ("ship.fill", "船乗り場")
        } else if firstPlaceType == "bus_station" {
            return ("bus.fill", "バス乗り場")
        } else {
            return ("", "")
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
}

// MARK: - Review Card
fileprivate struct ChatRoomReviewCardView: View {
    let review: GooglePlacesSearchResponseReview

    @State private var isPopover: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                WebImage(url: URL(string: review.authorAttribution?.photoUri ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(.gray.opacity(0.2))
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())

                Text(review.authorAttribution?.displayName ?? "匿名ユーザー")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
            }

            if let rating = review.rating {
                ratingTextView(rating: Double(rating), textSize: 10, starSize: 15)
            }

            Text(review.text?.text ?? "")
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.8))
                .lineLimit(5)
                .multilineTextAlignment(.leading)

            HStack(alignment: .center) {
                Spacer()
                Text("全て表示")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue.opacity(0.8))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: 230)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal, 5)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 3, y: 3)
        .shadow(color: .gray.opacity(0.3), radius: 1, x: 1, y: 1)
        .onTapGesture {
            withAnimation {
                self.isPopover.toggle()
            }
        }
        .popup(isPresented: $isPopover) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        WebImage(url: URL(string: review.authorAttribution?.photoUri ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(.gray.opacity(0.2))
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())

                        Text(review.authorAttribution?.displayName ?? "匿名ユーザー")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                    }

                    if let rating = review.rating {
                        ratingTextView(rating: Double(rating), textSize: 10, starSize: 15)
                    }

                    Text(review.text?.text ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 400)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            .padding(.horizontal, 20)
        } customize: { item in
            item
                .type(.floater())
                .animation(.spring())
                .closeOnTap(true)
                .closeOnTapOutside(true)
                .position(.center)
                .appearFrom(.centerScale)
                .backgroundColor(Color.black.opacity(0.5))
                .allowTapThroughBG(false)
        }
    }

    @ViewBuilder
    private func ratingTextView(rating: Double, textSize: CGFloat, starSize: CGFloat) -> some View {
        let integer = Int(rating)
        let fraction = Int(round(rating.truncatingRemainder(dividingBy: 1)))
        let nonStars = 5 - integer - fraction
        HStack {
            Text(String(rating))
                .font(.system(size: textSize, weight: .medium))
            HStack(alignment: .center) {
                ForEach(0..<integer, id: \.self) { _ in
                    Image("Star")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: starSize, height: starSize)
                }
                ForEach(0..<fraction, id: \.self) { _ in
                    Image("HalfStar")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: starSize, height: starSize)
                }
                ForEach(0..<nonStars, id: \.self) { _ in
                    Image("NonStar")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: starSize, height: starSize)
                }
            }
        }
    }
}
