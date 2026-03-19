//
//  LivingLoginSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/12.
//

import Foundation
import SwiftUI

struct LivingLoginSettingView: View {
    @EnvironmentObject private var settingRootViewModel: RootViewModel<ProfileLoginSettingRoot>
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color.backgroundColor.ignoresSafeArea()
            
            // Background Glows
            ZStack {
                Circle()
                    .fill(Color.selectedColor.opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(x: -120, y: -150)
                
                Circle()
                    .fill(Color.mainColor.opacity(0.15))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 120, y: 120)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 32) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.selectedColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.selectedColor.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Text("居住地を教えてください")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(Color.primary)
                    
                    Text("お住まいの地域に近いユーザーを見つけやすくなります。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // MARK: - Input Card
                VStack(alignment: .leading, spacing: 20) {
                    if profileLoginSettingViewModel.selectedPrefecture == nil {
                        // --- Prefecture Selection View ---
                        VStack(alignment: .leading, spacing: 12) {
                            Text("都道府県")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                            
                            ScrollView(showsIndicators: false) {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    ForEach(profileLoginSettingViewModel.prefectureList) { prefecture in
                                        Button(action: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                profileLoginSettingViewModel.selectedPrefecture = prefecture
                                            }
                                        }) {
                                            Text(prefecture.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.primary)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(Color.white.opacity(0.5))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.clear, lineWidth: 1.5)
                                                )
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                               removal: .move(edge: .leading).combined(with: .opacity)))
                    } else if let selectedPref = profileLoginSettingViewModel.selectedPrefecture,
                              let cities = profileLoginSettingViewModel.cityList[selectedPref.name] {
                        // --- City Selection View ---
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        profileLoginSettingViewModel.selectedPrefecture = nil
                                        profileLoginSettingViewModel.selectedCity = nil
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                        Text(selectedPref.name)
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.selectedColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.selectedColor.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                
                                Spacer()
                                
                                Text("市区町村を選択")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 8) {
                                    ForEach(cities) { city in
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                profileLoginSettingViewModel.selectedCity = city
                                            }
                                        }) {
                                            HStack {
                                                Text(city.cityName)
                                                    .font(.system(size: 15, weight: profileLoginSettingViewModel.selectedCity == city ? .bold : .medium))
                                                Spacer()
                                                if profileLoginSettingViewModel.selectedCity == city {
                                                    Image(systemName: "checkmark")
                                                        .foregroundStyle(Color.selectedColor)
                                                        .font(.system(size: 14, weight: .bold))
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                            .background(
                                                profileLoginSettingViewModel.selectedCity == city ?
                                                Color.selectedColor.opacity(0.1) : Color.black.opacity(0.03)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .foregroundStyle(profileLoginSettingViewModel.selectedCity == city ? Color.selectedColor : .primary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                               removal: .move(edge: .trailing).combined(with: .opacity)))
                    }
                }
                .padding(24)
                .frame(height: 440) // Fixed height for consistent transition
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .baseShadow()
                
                Spacer()
                
                // MARK: - Navigation Buttons
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            settingRootViewModel.pop(1)
                            profileLoginSettingViewModel.progress -= 1
                        }
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.mainColor)
                            .frame(width: 64, height: 64)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .baseShadow()
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            settingRootViewModel.push(.keyword)
                            profileLoginSettingViewModel.progress += 1
                        }
                    }) {
                        Text("次へ進む")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                LinearGradient(
                                    colors: [Color.mainColor, Color.mainColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .baseShadow()
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
    }
}
