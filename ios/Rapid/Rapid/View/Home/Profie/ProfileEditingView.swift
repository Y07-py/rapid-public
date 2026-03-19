//
//  ProfileEditingView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/01/21.
//

import Foundation
import SwiftUI
import PopupView
import SDWebImageSwiftUI

struct ProfileEditingView: View {
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @State private var focus: Bool = false
    @State private var isShowIntroductionTextWindow: Bool = false
    @State private var isHeightExpanded: Bool = false
    @State private var isLivingExpanded: Bool = false
    @State private var isProfessionExpanded: Bool = false
    @State private var isIncomeExpanded: Bool = false
    @State private var isBloodExpanded: Bool = false
    @State private var isSmokingExpanded: Bool = false
    @State private var isDrinkingExpanded: Bool = false
    @State private var isChildExpanded: Bool = false
    @State private var isAcademicExpanded: Bool = false
    @State private var isBodyExpanded: Bool = false
    @State private var isHolidayExpanded: Bool = false
    @State private var isMarriageExpanded: Bool = false
    @State private var isShowMBTISelectWindow: Bool = false
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            // Decorative background glow
            VStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -150, y: -100)
                Spacer()
                Circle()
                    .fill(Color.selectedColor.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: 150, y: 100)
            }
            .ignoresSafeArea()
            
            VStack(alignment: .center, spacing: .zero) {
                headerView
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 25) {
                        // 自己紹介文
                        settingSection(title: "自己紹介文") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(profileViewModel.introduction.isEmpty ? "自己紹介を入力しましょう" : profileViewModel.introduction)
                                    .font(.system(size: 15))
                                    .foregroundStyle(profileViewModel.introduction.isEmpty ? .gray.opacity(0.6) : .black.opacity(0.7))
                                    .lineSpacing(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(15)
                                    .background(Color.selectedColor.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .padding(.vertical, 10)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.isShowIntroductionTextWindow.toggle()
                                }
                            }
                        }
                        
                        // 基本プロフィール
                        settingSection(title: "基本プロフィール") {
                            VStack(spacing: 0) {
                                disclosureRow(title: "身長", value: "\(profileViewModel.height) cm", isExpanded: $isHeightExpanded) {
                                    Picker("身長", selection: $profileViewModel.height) {
                                        ForEach(140...220, id: \.self) { h in
                                            Text("\(String(h)) cm").tag(h)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .labelsHidden()
                                }
                                
                                editingDivider
                                
                                let living = profileViewModel.living
                                disclosureRow(title: "居住地", value: "\(living?.prefName ?? "未設定") \(living?.cityName ?? "")", isExpanded: $isLivingExpanded) {
                                    ScrollView {
                                        VStack(spacing: 0) {
                                            ForEach(Array(profileViewModel.cityNames.keys).sorted(), id: \.self) { pref in
                                                let cities = profileViewModel.cityNames[pref]!
                                                DisclosureGroup(pref) {
                                                    Picker("市区町村", selection: $profileViewModel.living) {
                                                        ForEach(cities) { city in
                                                            Text(city.cityName).tag(Optional(city))
                                                        }
                                                    }
                                                    .pickerStyle(.wheel)
                                                    .labelsHidden()
                                                }
                                                .font(.system(size: 15, weight: .medium))
                                                .padding(.vertical, 8)
                                                Divider()
                                            }
                                        }
                                    }
                                    .frame(height: 250)
                                }
                                
                                editingDivider
                                
                                disclosureRow(title: "職業", value: profileViewModel.profession?.name ?? "未設定", isExpanded: $isProfessionExpanded) {
                                    Picker("職業", selection: $profileViewModel.profession) {
                                        ForEach(profileViewModel.professions) { prof in
                                            Text(prof.name).tag(Optional(prof))
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .labelsHidden()
                                }
                                
                                editingDivider
                                
                                disclosureRow(title: "年収", value: profileViewModel.income?.income.rawValue ?? "未設定", isExpanded: $isIncomeExpanded) {
                                    Picker("年収", selection: $profileViewModel.income) {
                                        ForEach(profileViewModel.incomes) { income in
                                            Text(income.income.rawValue).tag(Optional(income))
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .labelsHidden()
                                }
                                
                                editingDivider
                                
                                disclosureRow(title: "体型", value: profileViewModel.bodyType, isExpanded: $isBodyExpanded) {
                                    Picker("体型", selection: $profileViewModel.bodyType) {
                                        ForEach(profileViewModel.bodyTypes, id: \.self) { body in
                                            Text(body).tag(body)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .labelsHidden()
                                }
                                
                                editingDivider
                                
                                disclosureRow(title: "血液型", value: profileViewModel.blood?.type.rawValue ?? "未設定", isExpanded: $isBloodExpanded) {
                                    Picker("血液型", selection: $profileViewModel.blood) {
                                        ForEach(profileViewModel.bloodTypes) { b in
                                            Text(b.type.rawValue).tag(Optional(b))
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .labelsHidden()
                                }
                                
                                editingDivider
                                
                                disclosureRow(title: "タバコ", value: profileViewModel.smoking?.style.rawValue ?? "未設定", isExpanded: $isSmokingExpanded) {
                                    Picker("タバコ", selection: $profileViewModel.smoking) {
                                        ForEach(profileViewModel.smokings) { s in
                                            Text(s.style.rawValue).tag(Optional(s))
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .labelsHidden()
                                }
                                
                                editingDivider
                                
                                disclosureRow(title: "お酒", value: profileViewModel.drinking?.style.rawValue ?? "未設定", isExpanded: $isDrinkingExpanded) {
                                    Picker("お酒", selection: $profileViewModel.drinking) {
                                        ForEach(profileViewModel.drinkings) { d in
                                            Text(d.style.rawValue).tag(Optional(d))
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .labelsHidden()
                                }
                                
                                editingDivider
                                
                                disclosureRow(title: "子どもの有無", value: profileViewModel.child?.status.rawValue ?? "未設定", isExpanded: $isChildExpanded) {
                                    Picker("子どもの有無", selection: $profileViewModel.child) {
                                        ForEach(profileViewModel.childStatus) { c in
                                            Text(c.status.rawValue).tag(Optional(c))
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .labelsHidden()
                                }
                                
                                editingDivider
                                
                                disclosureRow(title: "休日", value: profileViewModel.holidayType, isExpanded: $isHolidayExpanded) {
                                    Picker("休日", selection: $profileViewModel.holidayType) {
                                        ForEach(profileViewModel.holidayTypes, id: \.self) { holiday in
                                            Text(holiday).tag(holiday)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .labelsHidden()
                                }
                                
                                editingDivider
                                
                                disclosureRow(title: "結婚に対する意思", value: profileViewModel.thoughtMarriage, isExpanded: $isMarriageExpanded) {
                                    Picker("結婚に対する意思", selection: $profileViewModel.thoughtMarriage) {
                                        ForEach(profileViewModel.thoughtMarriages, id: \.self) { thought in
                                            Text(thought).tag(thought)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .labelsHidden()
                                }
                                
                                editingDivider
                                
                                disclosureRow(title: "最終学歴", value: profileViewModel.academicBackground?.academic.rawValue ?? "未設定", isExpanded: $isAcademicExpanded) {
                                    Picker("最終学歴", selection: $profileViewModel.academicBackground) {
                                        ForEach(profileViewModel.academics, id: \.self) { a in
                                            Text(a.academic.rawValue).tag(Optional(a))
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .labelsHidden()
                                }
                            }
                        }
                        
                        // MBTI
                        settingSection(title: "MBTI") {
                            VStack(alignment: .center, spacing: 15) {
                                if let mbti = profileViewModel.mbti {
                                    WebImage(url: mbti.thumbnailURL) { image in
                                        image.resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 20)
                                            .frame(width: 120, height: 120)
                                            .foregroundStyle(Color.secondaryBackgroundColor)
                                            .skelton(isActive: true)
                                    }
                                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                    
                                    Text(mbti.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.black.opacity(0.8))
                                } else {
                                    RoundedRectangle(cornerRadius: 20)
                                        .frame(width: 120, height: 120)
                                        .foregroundStyle(Color.selectedColor.opacity(0.05))
                                        .overlay {
                                            Image(systemName: "questionmark")
                                                .font(.system(size: 40, weight: .bold))
                                                .foregroundStyle(Color.selectedColor.opacity(0.3))
                                        }
                                    
                                    Text("未設定")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.gray)
                                }
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        self.isShowMBTISelectWindow.toggle()
                                    }
                                }) {
                                    Text("MBTIを選択する")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.mainColor)
                                        .clipShape(Capsule())
                                        .shadow(color: Color.mainColor.opacity(0.4), radius: 5, x: 0, y: 3)
                                }
                                .padding(.top, 5)
                            }
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                        }
                        
                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .overlay(alignment: .bottom) {
                saveButton
            }
            
            // Introduction Popup
            if isShowIntroductionTextWindow {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { isShowIntroductionTextWindow = false }
                    }
                
                VStack {
                    messageEditorView
                        .padding(.top, 40) // Adjusted for safe area/notch
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
            
            // MBTI Selection Popup
            if isShowMBTISelectWindow {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { isShowMBTISelectWindow = false }
                    }
                
                mbtiSelectView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .ignoresSafeArea(.keyboard)
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    homeRootViewModel.pop(1)
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color.secondaryBackgroundColor)
                    .clipShape(Circle())
            }
            
            Text("プロフィールの編集")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
                .padding(.leading, 10)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private func settingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black.opacity(0.55))
                .padding(.leading, 5)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color.secondaryBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
        }
    }
    
    @ViewBuilder
    private func disclosureRow<Content: View>(title: String, value: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.7))
                    Spacer()
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.selectedColor)
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.gray.opacity(0.3))
                        .padding(.leading, 5)
                }
                .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            
            if isExpanded.wrappedValue {
                content()
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    @ViewBuilder
    private var saveButton: some View {
        Button(action: {
            self.homeRootViewModel.pop(1)
            Task {
                await profileViewModel.updateProfile()
            }
        }) {
            HStack {
                Spacer()
                Text("保存する")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.vertical, 18)
            .background(Color.mainColor)
            .clipShape(Capsule())
            .shadow(color: Color.mainColor.opacity(0.4), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var messageEditorView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("自己紹介文を編集")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: { withAnimation { isShowIntroductionTextWindow = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.gray.opacity(0.3))
                }
            }
            
            TextEditorView(
                text: $profileViewModel.introduction,
                focus: $focus,
                placeHolder: "自己紹介を入力しましょう！",
                color: .white
            )
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Button(action: {
                withAnimation {
                    self.focus = false
                    isShowIntroductionTextWindow = false
                }
            }) {
                Text("入力完了")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.selectedColor)
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear { self.focus = true }
    }
    
    @ViewBuilder
    private var mbtiSelectView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("MBTIを選択")
                        .font(.system(size: 20, weight: .bold))
                    Text("現在の選択: \(profileViewModel.mbti?.name ?? "未設定")")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                }
                Spacer()
                Button(action: { withAnimation { isShowMBTISelectWindow = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.gray.opacity(0.3))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    if profileViewModel.mbtis.isEmpty {
                        ForEach(0..<4) { _ in
                            RoundedRectangle(cornerRadius: 20)
                                .frame(width: 160, height: 180)
                                .foregroundStyle(Color.secondaryBackgroundColor)
                                .skelton(isActive: true)
                        }
                    } else {
                        ForEach(profileViewModel.mbtis) { mbti in
                            VStack(spacing: 12) {
                                WebImage(url: mbti.thumbnailURL) { image in
                                    image.resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 15))
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 15)
                                        .frame(width: 120, height: 120)
                                        .foregroundStyle(Color.selectedColor.opacity(0.05))
                                }
                                
                                Text(mbti.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.7))
                            }
                            .padding(15)
                            .background(profileViewModel.mbti?.id == mbti.id ? Color.selectedColor.opacity(0.1) : Color.backgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(profileViewModel.mbti?.id == mbti.id ? Color.selectedColor : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.profileViewModel.mbti = mbti
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Button(action: { withAnimation { isShowMBTISelectWindow = false } }) {
                Text("決定")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.mainColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Color.secondaryBackgroundColor)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -10)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea()
    }
    
    private var editingDivider: some View {
        Divider().opacity(0.5)
    }
}
