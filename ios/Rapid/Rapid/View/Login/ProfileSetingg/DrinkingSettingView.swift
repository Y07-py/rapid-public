//
//  DrinkingSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/13.
//

import Foundation
import SwiftUI

struct DrinkingSettingView: View {
    @EnvironmentObject private var settingRootViewModel: RootViewModel<ProfileLoginSettingRoot>
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    
    var body: some View {
        ZStack {
            Color.mainColor.ignoresSafeArea()
            VStack(alignment: .center) {
                Text("🍺 飲酒の頻度")
                    .font(.title2)
                    .foregroundStyle(.black)
                
                ScrollView(.vertical) {
                    VStack(alignment: .center) {
                        ForEach(profileLoginSettingViewModel.drinkingList) { drinking in
                            Button(action: {
                                withAnimation {
                                    profileLoginSettingViewModel.selectedDrink = drinking
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Text(drinking.style.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(profileLoginSettingViewModel.selectedDrink == drinking ? .white : .gray)
                                    Spacer()
                                }
                                .padding()
                                .background {
                                    if profileLoginSettingViewModel.selectedDrink == drinking {
                                        RoundedRectangle(cornerRadius: 10)
                                            .foregroundStyle(.black)
                                    } else {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(lineWidth: 1)
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .padding(.horizontal, 5)
                            }
                        }
                    }
                }
                .frame(height: UIWindow().bounds.height * 0.75)
                .padding(.top, 20)

                HStack(alignment: .center) {
                    Button(action: {
                        withAnimation {
                            settingRootViewModel.pop(1)
                            profileLoginSettingViewModel.progress -= 1
                        }
                    }) {
                        Text("前へ")
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .foregroundStyle(.black)
                            }
                    }
                    Spacer()
                    Button(action: {
                        withAnimation {
//                            settingRootViewModel.push(.academicBackground)
                            profileLoginSettingViewModel.progress += 1
                        }
                    }) {
                        Text("次へ")
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .foregroundStyle(.black)
                            }
                    }
                }
                
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 20)
    }
}
