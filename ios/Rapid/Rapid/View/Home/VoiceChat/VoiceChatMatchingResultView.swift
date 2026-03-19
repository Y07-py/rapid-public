import SwiftUI
import SDWebImageSwiftUI

struct VoiceChatMatchingResultView: View {
    @EnvironmentObject var viewModel: VoiceChatViewModel
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .center, spacing: 32) {
                // Top Section: Matched Spot Info
                if let place = viewModel.matchedPlace {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("今日のスポット")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.black.opacity(0.8))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        
                        matchedSpotHeader(place: place)
                    }
                }
                
                // Information Section
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.thirdColor.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.thirdColor)
                    }
                    
                    VStack(spacing: 12) {
                        Text("ボイスチャット準備完了")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.black.opacity(0.8))
                        
                        Text("同じスポットを選んだお相手と\n10分間の通話を楽しむことができます。")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                    }
                }
                .padding(.top, 20)
                
                startVoiceChatButton
                
                Spacer().frame(height: 100)
            }
            .padding(.top, 10)
        }
    }
    
    @ViewBuilder
    private var startVoiceChatButton: some View {
        Button(action: {
            viewModel.joinVoiceChat()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                
                Text("ボイスチャットを始める")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                LinearGradient(
                    colors: [Color.thirdColor, Color.thirdColor.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.thirdColor.opacity(0.3), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private func matchedSpotHeader(place: GooglePlacesSearchPlaceWrapper) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Spot Image
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
                .frame(height: 200)
                .clipped()
            } else {
                Rectangle()
                    .foregroundStyle(LinearGradient(colors: [Color.mainColor.opacity(0.3), Color.thirdColor.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 200)
            }
            
            // Gradient Overlay
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
            
            // Integrated Spot Info
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.place?.displayName?.text ?? "不明なスポット")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(place.place?.formattedAddress ?? "住所情報なし")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if let rating = place.place?.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                }
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 12)
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
}
