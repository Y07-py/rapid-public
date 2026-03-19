//
//  BloodTypeSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/13.
//

import Foundation
import SwiftUI

struct BloodTypeSettingView: View {
    @EnvironmentObject private var settingRootViewModel: RootViewModel<ProfileLoginSettingRoot>
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    
    var body: some View {
        ZStack {
            Color.mainColor.ignoresSafeArea()
            VStack(alignment: .center, spacing: .zero) {
                Text("💉 血液型")
                    .font(.title3)
                    .foregroundStyle(.black)
                ScrollView(.vertical) {
                    VStack(alignment: .center) {
                        ForEach(profileLoginSettingViewModel.bloodTypeList) { bloodType in
                            Button(action: {
                                withAnimation {
                                    profileLoginSettingViewModel.selectedBloodType = bloodType
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Text(bloodType.type.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(profileLoginSettingViewModel.selectedBloodType == bloodType ? .white : .gray)
                                    Spacer()
                                }
                                .padding()
                                .background {
                                    if profileLoginSettingViewModel.selectedBloodType == bloodType {
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
//                            settingRootViewModel.push(.smoking)
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
                .padding(.top, 20)
                
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 20)
    }
}
