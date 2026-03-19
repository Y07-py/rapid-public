//
//  SmokingSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/13.
//

import Foundation
import SwiftUI

struct SmokingSettingView: View {
    @EnvironmentObject private var settingRootView: RootViewModel<ProfileLoginSettingRoot>
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    
    var body: some View {
        ZStack {
            Color.mainColor.ignoresSafeArea()
            VStack(alignment: .center) {
                Text("🚬 喫煙の頻度")
                    .font(.title2)
                    .foregroundStyle(.black)
                ScrollView(.vertical) {
                    VStack(alignment: .center) {
                        ForEach(profileLoginSettingViewModel.smokingStyleList) { smoking in
                            Button(action: {
                                withAnimation {
                                    profileLoginSettingViewModel.selectedSmokingStyle = smoking
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Text(smoking.style.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(profileLoginSettingViewModel.selectedSmokingStyle == smoking ? .white : .gray)
                                    Spacer()
                                }
                                .padding()
                                .background {
                                    if profileLoginSettingViewModel.selectedSmokingStyle == smoking {
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
                            settingRootView.pop(1)
                            profileLoginSettingViewModel.progress -= 1
                        }
                    }) {
                        Text("前へ")
                            .font(.headline)
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
//                            settingRootView.push(.drinking)
                            profileLoginSettingViewModel.progress += 1
                        }
                    }) {
                        Text("次へ")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .foregroundStyle(.black)
                            }
                    }
                }
                .padding(.top, 20)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 20)
    }
}
