import SwiftUI
import PopupView
import SDWebImageSwiftUI

struct VoiceChatVotingView: View {
    @EnvironmentObject var viewModel: VoiceChatViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @State private var isShowExplanation: Bool = false
    @State private var isShowSpotDetail: Bool = false
    
    var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: .zero) {
                headerView
                ScrollView(.vertical) {
                    VStack(spacing: 12) {
                        ForEach(viewModel.votingPlaces, id: \.id) { place in
                            spotCardView(place: place)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .overlay(alignment: .bottom) {
                if viewModel.joinedEventUser == nil {
                    voteButtonView
                } else {
                    waitingStatusView
                }
            }
        }
        .popup(isPresented: $isShowExplanation) {
            explanationPopupView
        } customize: { view in
            view
                .type(.floater())
                .position(.center)
                .animation(.spring())
                .closeOnTapOutside(true)
                .backgroundColor(.black.opacity(0.4))
        }
        .fullScreenCover(isPresented: $isShowSpotDetail) {
            VoiceChatSpotDetailView(isShowScreen: $isShowSpotDetail)
                .environmentObject(viewModel)
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("今日のスポット投票")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
                
                Button(action: {
                    withAnimation(.spring()) {
                        self.isShowExplanation = true
                    }
                }) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.mainColor.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
        }
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private var voteButtonView: some View {
        let isSelected = viewModel.selectedVotingPlace != nil
        
        Button(action: {
            Task {
                guard let user = profileViewModel.user else { return }
                await viewModel.submitVoiceChatVote(user: user)
            }
        }) {
            Text(isSelected ? "このスポットで投票" : "スポットを選択してください")
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .foregroundStyle(isSelected ? Color.thirdColor : Color.gray.opacity(0.5))
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
        }
        .disabled(!isSelected)
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var waitingStatusView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.thirdColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("投票が完了しました")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                    
                    Text("投票を集計中。19:00までお待ちください")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.gray)
                }
                
                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: -5)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    @ViewBuilder
    private func spotCardView(place: GooglePlacesSearchPlaceWrapper) -> some View {
        let isSelected = viewModel.selectedVotingPlace?.id == place.id
        
        Button(action: {
            if viewModel.joinedEventUser == nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    viewModel.selectedVotingPlace = place
                }
            }
        }) {
            HStack(spacing: 16) {
                // Photo Left
                if let photo = place.place?.photos?.first {
                    WebImage(url: photo.buildUrl()) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.1))
                            .skelton(isActive: true)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .foregroundStyle(.gray.opacity(0.1))
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    }
                    .frame(width: 100, height: 100)
                }
                
                // Info Right
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.place?.displayName?.text ?? "不明なスポット")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        Text(String(format: "%.1f", place.place?.rating ?? 0.0))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.black.opacity(0.6))
                    }
                    
                    Text(place.place?.formattedAddress ?? "住所情報なし")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Button(action: {
                        viewModel.detailViewingPlace = place
                        withAnimation(.spring()) {
                            self.isShowSpotDetail = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("詳細を見る")
                                .font(.system(size: 11, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Color.mainColor)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color.mainColor.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                // Checkmark for selection
                if isSelected {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.thirdColor)
                        
                        if viewModel.joinedEventUser != nil {
                            Text("投票済み")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.thirdColor)
                        }
                    }
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .foregroundStyle(isSelected ? (viewModel.joinedEventUser != nil ? Color.thirdColor.opacity(0.12) : Color.thirdColor.opacity(0.08)) : Color.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isSelected ? Color.thirdColor.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var explanationPopupView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("スポット投票の仕組み")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: { self.isShowExplanation = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.gray.opacity(0.4))
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                explanationItem(
                    icon: "location.fill",
                    title: "1. スポットを選ぶ",
                    description: "東京駅周辺の厳選された4つのスポットから、今日行ってみたい場所を1つ選びます。"
                )
                
                explanationItem(
                    icon: "clock.fill",
                    title: "2. 19:00にマッチング",
                    description: "毎日19時に集計が行われ、同じスポットを選んだ異性の中からランダムにマッチングされます。"
                )
                
                explanationItem(
                    icon: "mic.fill",
                    title: "3. 10分間のボイスチャット",
                    description: "お互いに「いいね」を送るとマッチング成立。その場で10分間のボイスチャットを楽しむことができます。"
                )
            }
            
            Button(action: { self.isShowExplanation = false }) {
                Text("閉じる")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.mainColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 10)
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 30)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
    
    @ViewBuilder
    private func explanationItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.mainColor)
                .frame(width: 32, height: 32)
                .background(Color.mainColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray)
                    .lineSpacing(2)
            }
        }
    }
}
