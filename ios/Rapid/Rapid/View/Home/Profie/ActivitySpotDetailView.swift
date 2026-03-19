//
//  ActivitySpotDetailView.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/05.
//

import SwiftUI

struct ActivitySpotDetailView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var recruitmentViewModel: RecruitmentViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.backgroundColor.ignoresSafeArea()
            
            if let activity = profileViewModel.selectedActivity {
                RecruitmentLocationView(recruitment: activity)
                    .environmentObject(recruitmentViewModel)
            }
            
            // Custom Header
            HStack {
                Button(action: {
                    withAnimation(.spring()) {
                        self.isPresented = false
                    }
                }) {
                    Circle()
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("スポット詳細")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                
                Spacer()
                
                // Placeholder for symmetry
                Circle()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .background {
                LinearGradient(
                    colors: [.black.opacity(0.5), .black.opacity(0.2), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onDisappear {
            // We might want to clear selectedActivity here, or keep it.
            // But usually, it's safer to clear it when closing.
            // profileViewModel.selectedActivity = nil
        }
    }
}
