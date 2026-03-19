import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct LocationSelectedListView: View {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var rootViewModel: RootViewModel<RecruitmentEditorRoot>
    
    @Binding var isShowScreen: Bool
    @State private var isAlert: Bool = false
    
    private let columns = [
        GridItem(.fixed((UIScreen.main.bounds.width - 56) / 2), spacing: 16),
        GridItem(.fixed((UIScreen.main.bounds.width - 56) / 2), spacing: 16)
    ]
    
    private var cardWidth: CGFloat {
        (UIScreen.main.bounds.width - 56) / 2
    }
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        planLimitInfoView
                        
                        if locationSelectViewModel.selectedCandidates.isEmpty {
                            emptyView
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(locationSelectViewModel.selectedCandidates) { wrapper in
                                    locationCardView(wrapper)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    rootViewModel.pop(1)
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.gray)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.8))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("スポットの再選択")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
            
            Spacer()
            
            // Selection count indicator
            ZStack {
                Circle()
                    .fill(Color.selectedColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Text("\(locationSelectViewModel.recruitmentSelectedIds.count)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.selectedColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.backgroundColor.opacity(0.8))
        .background(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private var planLimitInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(profileViewModel.isPremium ? "プレミアムプラン" : "フリープラン")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(profileViewModel.isPremium ? Color.thirdColor : Color.subscriptionColor)
                    .clipShape(Capsule())
                
                Spacer()
                
                let limit = profileViewModel.isPremium ? 5 : 3
                Text("最大 \(limit) 箇所まで選択可能")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.gray)
            }
            
            if !profileViewModel.isPremium {
                Text("プレミアムプランに加入すると最大5箇所まで選択できます")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.selectedColor.opacity(0.8))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 60))
                .foregroundStyle(Color.mainColor.opacity(0.2))
            
            Text("候補がありません")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black.opacity(0.6))
            
            Text("ボックスにスポットを追加してから\nこの画面で選択してください")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    @ViewBuilder
    private func locationCardView(_ wrapper: GooglePlacesSearchPlaceWrapper) -> some View {
        let isSelected = locationSelectViewModel.recruitmentSelectedIds.contains(wrapper.place?.id ?? "")
        let limit = profileViewModel.isPremium ? 5 : 3
        
        VStack(alignment: .leading, spacing: 0) {
            // Clickable area for details
            VStack(alignment: .leading, spacing: 0) {
                // Image
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
                    .frame(width: cardWidth)
                    .frame(height: 120)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: cardWidth)
                        .frame(height: 120)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundStyle(.gray.opacity(0.3))
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(wrapper.place?.displayName?.text ?? "不明な場所")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                        .lineLimit(1)
                    
                    Text(wrapper.place?.formattedAddress ?? "")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                locationSelectViewModel.selectedPlace = wrapper
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    rootViewModel.push(.detail)
                }
            }
            
            Divider()
                .padding(.horizontal, 10)
            
            // Action buttons row
            HStack {
                // Remove from selection Button
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        let _ = locationSelectViewModel.recruitmentSelectedIds.remove(wrapper.place?.id ?? "")
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!isSelected)
                .opacity(isSelected ? 1 : 0.3)
                
                Spacer()
                
                // Select Button
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if isSelected {
                            locationSelectViewModel.recruitmentSelectedIds.remove(wrapper.place?.id ?? "")
                        } else if locationSelectViewModel.recruitmentSelectedIds.count < limit {
                            locationSelectViewModel.recruitmentSelectedIds.insert(wrapper.place?.id ?? "")
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isSelected ? "checkmark" : "plus")
                        Text(isSelected ? "選択中" : "選択")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isSelected ? .white : Color.selectedColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.selectedColor : Color.selectedColor.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.selectedColor : Color.clear, lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
