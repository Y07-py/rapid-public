//
//  AnnualIncomeSettingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/12.
//

import Foundation
import SwiftUI

struct AnnualIncomeSettingView: View {
    @EnvironmentObject private var settingRootViewModel: RootViewModel<ProfileLoginSettingRoot>
    @EnvironmentObject private var profileLoginSettingViewModel: ProfileLoginSettingViewModel
    
    var body: some View {
        ZStack {
            Color.mainColor.ignoresSafeArea()
            VStack(alignment: .center, spacing: .zero) {
                Text("💰 年収")
                    .font(.title2)
                    .foregroundStyle(.black)
                ScrollView(.vertical) {
                    VStack {
                        ForEach(profileLoginSettingViewModel.annualIncomeList) { income in
                            Button(action: {
                                withAnimation {
                                    profileLoginSettingViewModel.selectedAnnualIncome = income
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Text(income.income.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(profileLoginSettingViewModel.selectedAnnualIncome == income ? .white : .gray)
                                    Spacer()
                                }
                                .padding()
                                .background {
                                    if profileLoginSettingViewModel.selectedAnnualIncome == income {
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
//                            settingRootViewModel.push(.profession)
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
