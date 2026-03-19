import SwiftUI
import Lottie

struct VoiceChatWaitingView: View {
    @EnvironmentObject var viewModel: VoiceChatViewModel
    @State private var circleScale: CGFloat = 1.0
    @State private var circleOpacity: Double = 0.5
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated Radar/Pulse effect
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.thirdColor, lineWidth: 2)
                        .scaleEffect(circleScale + CGFloat(i) * 0.4)
                        .opacity(circleOpacity - Double(i) * 0.15)
                }
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.thirdColor, Color.thirdColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.thirdColor.opacity(0.4), radius: 20)
                
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 300, height: 300)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                    circleScale = 2.0
                    circleOpacity = 0.0
                }
            }
            
            VStack(spacing: 16) {
                Text("マッチング相手を探しています...")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                
                Text("\(viewModel.matchedPlace?.place?.displayName?.text ?? "選択したスポット") で待機中")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.gray)
                
                Text("同じスポットを選んだお相手が参加すると\n自動的にボイスチャットが開始されます。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: {
                viewModel.leaveVoiceChat()
            }) {
                Text("キャンセル")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.gray)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundColor)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
