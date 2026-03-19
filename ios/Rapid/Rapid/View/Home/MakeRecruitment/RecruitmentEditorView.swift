//
//  RecruitmentEditorView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/02.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import PopupView

public enum RecruitmentEditorViewType: Hashable {
    case firstView
    case secondView
}

struct RecruitmentEditorView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @EnvironmentObject private var rootViewModel: RootViewModel<RecruitmentEditorRoot>
    
    @Binding var isShowScreen: Bool
    let viewType: RecruitmentEditorViewType
    
    @State private var isShowCalendarSheet: Bool = false
    @State private var dummyFocus: Bool = false
    @State private var viewOffset: CGFloat = .zero
    @State private var isShowingNoSpotAlert: Bool = false
    
    @FocusState private var focus: Bool
    
    private let calendar: Calendar = {
        let calendar = Calendar(identifier: .gregorian)
        return calendar
    }()
    
    private let dateFormatter: DateFormatter = {
       let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        
        return formatter
    }()
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            
            VStack(alignment: .leading, spacing: 0) {
                headerView
                
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 32) {
                        // Selected Spots Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.mainColor)
                                
                                Text("選択したスポット")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.gray)
                                
                                Spacer()
                                
                                if locationSelectViewModel.directRecruitmentPlace == nil {
                                    Text("\(locationSelectViewModel.selectedCandidates.filter { locationSelectViewModel.recruitmentSelectedIds.contains($0.place?.id ?? "") }.count)件")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.mainColor)
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal) {
                                HStack(alignment: .top, spacing: 16) {
                                     let candidates = locationSelectViewModel.directRecruitmentPlace != nil ? [locationSelectViewModel.directRecruitmentPlace!] : locationSelectViewModel.selectedCandidates
                                     let selectedSpots = candidates.filter { wrapper in
                                         locationSelectViewModel.recruitmentSelectedIds.contains(wrapper.place?.id ?? "")
                                     }
                                     ForEach(selectedSpots) { wrapper in
                                         locationCardView(wrapper)
                                     }
                                 }
                                .padding(.horizontal, 24)
                            }
                            .scrollIndicators(.hidden)
                        }
                        .padding(.top, 24)
                        
                        // Message Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "text.bubble.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.mainColor)
                                
                                Text("メッセージ")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.gray)
                            }
                            .padding(.horizontal, 24)
                                     
                            TextField("メッセージの入力", text: $locationSelectViewModel.messageText, axis: .vertical)
                                .focused($focus)
                                .font(.system(size: 16))
                                .padding(16)
                                .frame(height: 120, alignment: .topLeading)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                                .padding(.horizontal, 20)
                        }
                        
                        // Schedule Settings Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.mainColor)
                                
                                Text("予定の設定")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.gray)
                            }
                            .padding(.horizontal, 24)
                            
                            VStack(spacing: 0) {
                                // Calendar Row
                                Menu {
                                    Button(action: { locationSelectViewModel.dateType = .free }) {
                                        Label("相手と相談して決める", systemImage: "person.2.fill")
                                    }
                                    
                                    Button(action: {
                                        locationSelectViewModel.dateType = .date
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            self.isShowCalendarSheet.toggle()
                                        }
                                    }) {
                                        Label("日程を設定する", systemImage: "calendar.badge.plus")
                                    }
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Color.mainColor)
                                            .frame(width: 32)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("日程")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.black.opacity(0.8))
                                            
                                            Group {
                                                switch locationSelectViewModel.dateType {
                                                case .free:
                                                    Text("相手と相談して決める")
                                                case .date:
                                                    let startDate = locationSelectViewModel.recruitmentStartDate
                                                    let endDate = locationSelectViewModel.recruitmentEndDate
                                                    if dateSame(startDate: startDate, endDate: endDate) {
                                                        Text(dateFormat(startDate))
                                                    } else {
                                                        Text("\(dateFormat(startDate)) 〜 \(dateFormat(endDate))")
                                                    }
                                                }
                                            }
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.gray.opacity(0.3))
                                    }
                                    .padding(16)
                                }
                            }
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                            .padding(.horizontal, 20)
                        }
                        
                        // Spot Selection Section
                        if locationSelectViewModel.directRecruitmentPlace == nil {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.subFontColor)
                                    
                                    Text("スポットの選択")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.gray)
                                }
                                .padding(.horizontal, 24)
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        rootViewModel.push(.candidateList)
                                    }
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "archivebox.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Color.subFontColor)
                                            .frame(width: 32)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("スポットを再選択する")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.black.opacity(0.8))
                                            
                                            Text("一度ボックスに戻ってスポットを選び直します")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.gray.opacity(0.3))
                                    }
                                    .padding(16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        Spacer().frame(height: 120)
                    }
                }
                .scrollIndicators(.hidden)
                .offset(y: viewOffset)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onTapGesture {
            self.focus = false
        }
        .overlay(alignment: .bottom) {
            Button(action: {
                if locationSelectViewModel.recruitmentSelectedIds.isEmpty {
                    isShowingNoSpotAlert = true
                    return
                }
                
                Task {
                    await self.locationSelectViewModel.postRecruitment {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.isShowScreen.toggle()
                        }
                    }
                }
            }) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .bold))
                    
                    Text("ポスト")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .frame(height: 56)
                .background(Color.mainColor)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 35)
        }
        .sheet(isPresented: $isShowCalendarSheet) {
            RecruitmentEditorCalendarView()
                .environmentObject(locationSelectViewModel)
                .presentationDetents([.fraction(0.8)])
        }
        .ignoresSafeArea(.keyboard)
         .alert("スポット未選択", isPresented: $isShowingNoSpotAlert) {
             Button("OK", role: .cancel) { }
         } message: {
             Text("スポットを1箇所以上選択してください。")
         }
         .onAppear {
             if locationSelectViewModel.recruitmentSelectedIds.isEmpty {
                 locationSelectViewModel.recruitmentSelectedIds = Set(locationSelectViewModel.selectedCandidates.compactMap { $0.place?.id })
             }
         }
     }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                if viewType == .secondView {
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.rootViewModel.pop(1)
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.gray)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.isShowScreen.toggle()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.gray)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
                
                Text("新規募集")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Spacer()
                
                // Invisible placeholder for centering
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.top, 10)
        .background(Color.backgroundColor.opacity(0.8))
        .background(.ultraThinMaterial)
        .zIndex(1)
    }
    
    @ViewBuilder
    private func locationCardView(_ wrapper: GooglePlacesSearchPlaceWrapper) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Section with Rating
            ZStack(alignment: .topTrailing) {
                if let photo = wrapper.place?.photos?.first {
                    WebImage(url: photo.buildUrl()) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .skelton(isActive: true)
                    }
                    .frame(width: 240, height: 160)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 240, height: 160)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundStyle(.gray.opacity(0.3))
                        }
                }
                
                // Rating Badge
                if let rating = wrapper.place?.rating, rating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.mainColor)
                    .clipShape(Capsule())
                    .padding(8)
                }
            }
            
            // Content Section
            VStack(alignment: .leading, spacing: 4) {
                Text(wrapper.place?.displayName?.text ?? "不明な場所")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.selectedColor)
                    
                    Text(wrapper.place?.formattedAddress ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
            }
            .padding(12)
        }
        .frame(width: 240)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        .onTapGesture {
            locationSelectViewModel.selectedPlace = wrapper
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                rootViewModel.push(.detail)
            }
        }
    }

    private var safeAreaInsets: UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return .zero }
        return window.safeAreaInsets
    }
    
    private func dateSame(startDate start: Date, endDate end: Date) -> Bool {
        return calendar.isDate(start, equalTo: end, toGranularity: .day)
    }
    
    private func dateFormat(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
}


// MARK: - Recruitment Calendar
fileprivate struct RecruitmentEditorCalendarView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    private var yearDates: [Date] = {
        let calendar = Calendar.current
        let now = Date.now
        guard let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return [] }
        return (0..<12).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: startOfCurrentMonth)
        }
    }()
    
    private let dateMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()
    
    private let dateDayFormatter: DateFormatter = {
       let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 0), count: 7)
    private let weekDaylabels: [String] = ["日", "月", "火", "水", "木", "金", "土"]
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView(.vertical) {
                VStack(alignment: .center, spacing: 30) {
                    ForEach(yearDates, id: \.self) { month in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(dateMonthFormat(date: month))
                                .font(.system(size: 18, weight: .bold))
                                .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: columns, spacing: 0) {
                                ForEach(weekDaylabels, id: \.self) { label in
                                    Text(label)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.gray)
                                        .frame(height: 30)
                                }
                                
                                ForEach(monthDates(for: month), id: \.self) { day in
                                    dayCell(day: day, month: month)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    @ViewBuilder
    private func dayCell(day: Date, month: Date) -> some View {
        let isSelected = selectedDate(day: day)
        let isStart = sameStartDay(day: day)
        let isEnd = sameEndDay(day: day)
        let isInMonth = inMonthDay(day: day, month: month)
        
        let weekday = Calendar.current.component(.weekday, from: day)
        let isSunday = weekday == 1
        let isSaturday = weekday == 7
        
        Button(action: {
            if isInMonth && !dayPassed(date: day) {
                locationSelectViewModel.updateSelectedDate(date: day)
            }
        }) {
            ZStack {
                if isToday(day: day) && isInMonth {
                    if !(isSelected && isInMonth) {
                        Circle()
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                            .frame(width: 36, height: 36)
                    }
                }
                
                if isSelected && isInMonth {
                    let cornerRadius: CGFloat = 15
                    UnevenRoundedRectangle(
                        topLeadingRadius: (isStart || isSunday) ? cornerRadius : 0,
                        bottomLeadingRadius: (isStart || isSunday) ? cornerRadius : 0,
                        bottomTrailingRadius: (isEnd || isSaturday) ? cornerRadius : 0,
                        topTrailingRadius: (isEnd || isSaturday) ? cornerRadius : 0
                    )
                    .foregroundStyle(Color.selectedColor.opacity(0.6))
                    .padding(.vertical, 4)
                }
                
                Text(dateDayFormat(date: day))
                    .font(.system(size: 15, weight: (isStart || isEnd) ? .bold : .medium))
                    .foregroundStyle(isStart || isEnd ? .white : dayColor(date: day, month: month))
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .disabled(!isInMonth || dayPassed(date: day))
        .opacity(isInMonth ? 1 : 0)
    }
    
    // --- Helper Functions ---
    private func dateMonthFormat(date: Date) -> String {
        return dateMonthFormatter.string(from: date)
    }
    
    private func dateDayFormat(date: Date) -> String {
        return dateDayFormatter.string(from: date)
    }
    
    private func monthDates(for date: Date) -> [Date] {
        let calendar = Calendar.current
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [] }
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        let monthDates = range.compactMap({ calendar.date(byAdding: .day, value: $0 - 1, to: start) })
        
        let firstDate = monthDates.first!
        let startOffset = calendar.component(.weekday, from: firstDate)
        
        var allDates: [Date] = []
        for i in (1..<startOffset).reversed() {
            if let d = calendar.date(byAdding: .day, value: -i, to: firstDate) {
                allDates.append(d)
            }
        }
        allDates.append(contentsOf: monthDates)
        let remain = 42 - allDates.count
        for i in 1...remain {
            if let d = calendar.date(byAdding: .day, value: i, to: monthDates.last!) {
                allDates.append(d)
            }
        }
        return allDates
    }
    
    private func dayPassed(date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: date) < calendar.startOfDay(for: .now)
    }
    
    private func dayColor(date: Date, month: Date) -> Color {
        if dayPassed(date: date) { return .gray.opacity(0.4) }
        return .black.opacity(0.8)
    }
    
    private func inMonthDay(day: Date, month: Date) -> Bool {
        Calendar.current.isDate(day, equalTo: month, toGranularity: .month)
    }
    
    private func isToday(day: Date) -> Bool {
        Calendar.current.isDate(day, equalTo: .now, toGranularity: .day)
    }
    
    private func selectedDate(day: Date) -> Bool {
        let calendar = Calendar.current
        
        // Normalize 00:00:00
        let normalizedDay = calendar.startOfDay(for: day)
        let normalizedStart = calendar.startOfDay(for: locationSelectViewModel.recruitmentStartDate)
        let normalizedEnd = calendar.startOfDay(for: locationSelectViewModel.recruitmentEndDate)
        
        return normalizedDay >= normalizedStart && normalizedDay <= normalizedEnd
    }
    
    private func sameStartDay(day: Date) -> Bool {
        Calendar.current.isDate(day, equalTo: locationSelectViewModel.recruitmentStartDate, toGranularity: .day)
    }
    
    private func sameEndDay(day: Date) -> Bool {
        Calendar.current.isDate(day, equalTo: locationSelectViewModel.recruitmentEndDate, toGranularity: .day)
    }
}
