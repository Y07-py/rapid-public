//
//  ProfileView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/22.
//

import SwiftUI
import SDWebImageSwiftUI
import RevenueCat

fileprivate enum ProfileTabType: Hashable {
    case profile
    case history
}

struct ProfileView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @EnvironmentObject private var recruitmentViewModel: RecruitmentViewModel
    
    @State private var selectedTabIndex: Int = 0
    @State private var selectedTabType: ProfileTabType = .profile
    @State private var isShowProfileThumbnailSettingWindow: Bool = false
    @State private var isShowMessageBoxWindow: Bool = false
    @State private var isShowActivityDetail: Bool = false
    @State private var isShowAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isShowPointPurchasePayWall: Bool = false
    @State private var isShowPremiumPayWall: Bool = false
    
    @Namespace private var namespace
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            // Decorative background glow
            VStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.25))
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
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 25) {
                    profileHeader
                        .padding(.top, 20) // Manual top padding to avoid notch
                    
                    profileHeroCard
                    
                    tabSwitcher
                    
                    if selectedTabIndex == 0 {
                        ProfileAttributeView()
                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                                  removal: .move(edge: .trailing).combined(with: .opacity)))
                    } else {
                        ProfileHistoryView(isShowDetail: $isShowActivityDetail, alertMessage: $alertMessage, isShowAlert: $isShowAlert)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                  removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .fullScreenCover(isPresented: $isShowProfileThumbnailSettingWindow) {
            ProfileThumbnailSettingView(isShowWindow: $isShowProfileThumbnailSettingWindow)
                .environmentObject(profileViewModel)
        }
        .fullScreenCover(isPresented: $isShowMessageBoxWindow) {
            ProfileMessageBoxView(isShowWindow: $isShowMessageBoxWindow)
                .environmentObject(profileViewModel)
        }
        .fullScreenCover(isPresented: $isShowActivityDetail) {
            ActivitySpotDetailView(isPresented: $isShowActivityDetail)
                .environmentObject(profileViewModel)
                .environmentObject(recruitmentViewModel)
        }
        .alert(isPresented: $isShowAlert) {
            Alert(title: Text("募集投稿"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(isPresented: $isShowPointPurchasePayWall) {
            PointPurchasePayWallView(isPresented: $isShowPointPurchasePayWall)
                .environmentObject(profileViewModel)
        }
        .fullScreenCover(isPresented: $isShowPremiumPayWall) {
            PremiumPayWallView(isPresented: $isShowPremiumPayWall)
                .environmentObject(profileViewModel)
        }
    }
    
    @ViewBuilder
    private var profileHeader: some View {
        HStack {
            Text("マイページ")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
            
            Spacer()
            
            HStack(spacing: 15) {
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.isShowMessageBoxWindow.toggle()
                    }
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "tray")
                            .font(.system(size: 22))
                            .foregroundStyle(.black.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .background(Color.secondaryBackgroundColor)
                            .clipShape(Circle())
                        
                        if profileViewModel.unReadNotoficationMessageCount > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Text("\(profileViewModel.unReadNotoficationMessageCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.homeRootViewModel.push(.setting)
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22))
                        .foregroundStyle(.black.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .background(Color.secondaryBackgroundColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var profileHeroCard: some View {
        let isWoman = (profileViewModel.user?.user.sex ?? "man") == "woman"
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                thumbnailProfile
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(profileViewModel.user?.user.userName ?? "Guest User")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                    
                    HStack(spacing: 8) {
                        if profileViewModel.isIdentityVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.selectedColor)
                            Text("本人確認済み")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.6))
                        } else {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundStyle(.gray.opacity(0.5))
                            Text("本人確認未完了")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.gray.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((profileViewModel.isIdentityVerified ? Color.selectedColor : Color.gray).opacity(0.1))
                    .clipShape(Capsule())
                }
                Spacer()
            }
            
            Divider()
                .background(Color.black.opacity(0.05))
            
            HStack(spacing: 15) {
                // Points Card
                Button(action: {
                    isShowPointPurchasePayWall = true
                }) {
                    dashboardItem(
                        icon: "Coin",
                        title: "保有ポイント",
                        value: "\(profileViewModel.totalPoint) P",
                        color: Color.mainColor,
                        isFullWidth: isWoman
                    )
                }
                .buttonStyle(.plain)
                
                if !isWoman {
                    // Subscription Card
                    Button(action: {
                        isShowPremiumPayWall = true
                    }) {
                        dashboardItem(
                            icon: "Puzzle Piece",
                            title: "プラン",
                            value: (profileViewModel.user?.user.subscriptionStatus ?? "free") == "free" ? "無料プラン" : "有料プラン",
                            color: Color.selectedColor
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.secondaryBackgroundColor)
                .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 10)
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func dashboardItem(icon: String, title: String, value: String, color: Color, isFullWidth: Bool = false) -> some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.gray)
                }
                
                Text(value)
                    .font(.system(size: isFullWidth ? 22 : 18, weight: .bold))
                    .foregroundStyle(color)
            }
            
            if isFullWidth {
                Spacer()
                
                HStack(spacing: 8) {
                    Text("ポイント購入")
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                }
                .foregroundStyle(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    @ViewBuilder
    private var thumbnailProfile: some View {
        Button(action: {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.isShowProfileThumbnailSettingWindow.toggle()
            }
        }) {
            ZStack(alignment: .bottomTrailing) {
                let iconImage: UserProfileImage? = {
                    if let firstDraft = profileViewModel.userProfileImages.first,
                       (firstDraft.image != nil || firstDraft.isUnderReview) {
                        return firstDraft
                    }
                    return profileViewModel.user?.profileImages.first
                }()
                
                ZStack {
                    if let image = iconImage {
                        ZStack(alignment: .center) {
                            Group {
                                if let data = image.image, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                } else if let url = image.imageURL {
                                    WebImage(url: url) { view in
                                        view
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                } else {
                                    Image("nontitle_cover")
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                            
                            if image.isUnderReview {
                                ZStack {
                                    Circle()
                                        .fill(.black.opacity(0.35))
                                        .background(.ultraThinMaterial)
                                    VStack(spacing: 2) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 14))
                                        Text("審査中")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundStyle(.white)
                                }
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                            }
                        }
                    } else {
                        Image("nontitle_cover")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    }
                }
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(LinearGradient(colors: [Color.mainColor, Color.selectedColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 5, y: 5)
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            tabButton(type: .profile, label: "プロフィール", index: 0)
            tabButton(type: .history, label: "アクティビティ", index: 1)
        }
        .padding(6)
        .background(Color.secondaryBackgroundColor)
        .clipShape(Capsule())
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func tabButton(type: ProfileTabType, label: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.selectedTabIndex = index
                self.selectedTabType = type
            }
            if type == .history {
                profileViewModel.fetchActivity()
            }
        }) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(selectedTabType == type ? .white : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    if selectedTabType == type {
                        Capsule()
                            .fill(LinearGradient(colors: [Color.selectedColor, Color.selectedColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .matchedGeometryEffect(id: "activeTab", in: namespace)
                            .shadow(color: Color.selectedColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct ProfileAttributeView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    @EnvironmentObject private var homeRootViewModel: RootViewModel<HomeRoot>
    
    var body: some View {
        VStack(spacing: 25) {
            // Bio Section
            sectionCard(title: "自己紹介") {
                VStack(alignment: .leading, spacing: 15) {
                    Text(profileViewModel.introduction.isEmpty ? "自己紹介文を設定して、自分をアピールしましょう！" : profileViewModel.introduction)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black.opacity(0.7))
                        .lineSpacing(4)
                    
                    Button(action: {
                        homeRootViewModel.push(.editing)
                    }) {
                        HStack {
                            Text("編集する")
                                .font(.system(size: 14, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Color.selectedColor)
                    }
                }
            }
            
            // MBTI Section
            sectionCard(title: "性格診断 (MBTI)") {
                HStack(spacing: 20) {
                    if let mbti = profileViewModel.mbti {
                        WebImage(url: mbti.thumbnailURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.1)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(mbti.name)
                                .font(.system(size: 18, weight: .bold))
                            Text("あなたの価値観や性格のタイプを表示します")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                    } else {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .background(Color.secondaryBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("未設定")
                                .font(.system(size: 18, weight: .bold))
                            Text("性格診断を受けてプロフィールを充実させましょう")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.gray.opacity(0.5))
                }
                .onTapGesture {
                    homeRootViewModel.push(.editing)
                }
            }
            
            // Basic Info Section
            sectionCard(title: "基本プロフィール") {
                let user = profileViewModel.user?.user
                VStack(spacing: 0) {
                    profileInfoRow(icon: "ruler", label: "身長", value: user?.height?.description, unit: "cm")
                    infoDivider
                    profileInfoRow(icon: "mappin.and.ellipse", label: "居住地", value: user?.residence)
                    infoDivider
                    profileInfoRow(icon: "briefcase", label: "職業", value: user?.profession)
                    infoDivider
                    profileInfoRow(icon: "yensign.circle", label: "年収", value: user?.income)
                    infoDivider
                    profileInfoRow(icon: "person.fill", label: "体型", value: user?.bodyType)
                    infoDivider
                    profileInfoRow(icon: "drop.fill", label: "血液型", value: user?.bloodType)
                    infoDivider
                    profileInfoRow(icon: "smoke.fill", label: "タバコ", value: user?.smokingFrequency)
                    infoDivider
                    profileInfoRow(icon: "wineglass.fill", label: "お酒", value: user?.drinkingFrequency)
                    infoDivider
                    profileInfoRow(icon: "figure.and.child.holdinghands", label: "子どもの有無", value: user?.childStatus)
                    infoDivider
                    profileInfoRow(icon: "calendar", label: "休日", value: user?.holidayType)
                    infoDivider
                    profileInfoRow(icon: "heart.fill", label: "結婚に対する意思", value: user?.thoughtMarriage)
                    infoDivider
                    profileInfoRow(icon: "graduationcap.fill", label: "最終学歴", value: user?.academicBackground)
                }
            }
            
            // Privacy Note
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                Text("※未設定の項目は、タイムライン上で他のユーザーには表示されません。")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.gray.opacity(0.6))
            .padding(.top, -10)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black.opacity(0.55))
                .padding(.leading, 5)
            
            VStack(alignment: .leading) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.secondaryBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
        }
    }
    
    @ViewBuilder
    private func profileInfoRow(icon: String, label: String, value: String?, unit: String = "") -> some View {
        Button(action: {
            homeRootViewModel.push(.editing)
        }) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                    .background(Color.selectedColor.opacity(0.1))
                    .foregroundStyle(Color.selectedColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.7))
                
                Spacer()
                
                Text(value != nil ? "\(value!)\(unit)" : "未設定")
                    .font(.system(size: 15))
                    .foregroundStyle(value != nil ? .black.opacity(0.6) : .gray.opacity(0.4))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.3))
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
    
    private var infoDivider: some View {
        Divider().padding(.leading, 47).opacity(0.5)
    }
}

fileprivate struct ProfileHistoryView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @Binding var isShowDetail: Bool
    @Binding var alertMessage: String
    @Binding var isShowAlert: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            if profileViewModel.isLoadingActivity {
                VStack(spacing: 20) {
                    ForEach(0..<3) { _ in
                        HistoryCardSkeleton()
                    }
                }
                .padding(.horizontal, 20)
            } else if profileViewModel.myRecruitments.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 50))
                        .foregroundStyle(.gray.opacity(0.2))
                    Text("履歴はまだありません")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.gray.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                VStack(spacing: 20) {
                    ForEach(profileViewModel.myRecruitments) { recruitment in
                        RecruitmentHistoryCard(recruitment: recruitment, isShowDetail: $isShowDetail, alertMessage: $alertMessage, isShowAlert: $isShowAlert)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

fileprivate struct HistoryCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 100, height: 14)
                    .clipShape(Capsule())
                Spacer()
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 50, height: 18)
                    .clipShape(Capsule())
            }
            
            // Message
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Places
            HStack(spacing: 12) {
                ForEach(0..<2) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 120, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Divider().opacity(0.5)
            
            // Footer
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 40, height: 12)
                Spacer()
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 90, height: 30)
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .skelton(isActive: true)
    }
}

fileprivate struct RecruitmentHistoryCard: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    
    let recruitment: RecruitmentWithUserProfile
    @Binding var isShowDetail: Bool
    @Binding var alertMessage: String
    @Binding var isShowAlert: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header: Date and Status
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(formattedDate(recruitment.recruitment.recruitmentWithRelations.postDate))
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.gray)
                
                Spacer()
                
                statusBadge(recruitment.recruitment.recruitmentWithRelations.status)
            }
            
            // Message
            if let message = recruitment.recruitment.recruitmentWithRelations.message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black.opacity(0.8))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(15)
                    .background(Color.selectedColor.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            
            // Places
            if !recruitment.places.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recruitment.places) { wrapper in
                            compactPlaceView(wrapper: wrapper)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            Divider()
                .background(Color.black.opacity(0.05))
            
            // Footer: Stats and Action
            HStack {
                HStack(spacing: 15) {
                    Label("\(recruitment.recruitment.recruitmentWithRelations.viewCount ?? 0)", systemImage: "eye.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.gray.opacity(0.6))
                }
                
                Spacer()
                
                let isActive = recruitment.recruitment.recruitmentWithRelations.status == "active"
                
                Button(action: {
                    if isActive {
                        Task { @MainActor in
                            await self.locationSelectViewModel.closeActiveRecruitment()
                        }
                    } else {
                        self.profileViewModel.rePost(recruitment: recruitment) { success in
                            if success {
                                self.alertMessage = "投稿を受け付けました。審査が完了しだい、タイムラインに表示されます。"
                                self.isShowAlert = true
                            } else {
                                self.alertMessage = "すでに現在進行中の募集があるか、投稿に失敗しました。"
                                self.isShowAlert = true
                            }
                        }
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: isActive ? "xmark.circle" : "arrow.clockwise")
                        Text(isActive ? "投稿をキャンセル" : "この内容で再投稿")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isActive ? .red : Color.selectedColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background((isActive ? Color.red : Color.selectedColor).opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
        .contentShape(Rectangle())
        .onTapGesture {
            profileViewModel.selectedActivity = recruitment
            withAnimation(.spring()) {
                isShowDetail = true
            }
        }
    }
    
    @ViewBuilder
    private func statusBadge(_ status: String?) -> some View {
        let isActive = status == "active"
        Text(isActive ? "募集中" : "終了")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Color.mainColor : Color.gray.opacity(0.4))
            .clipShape(Capsule())
    }
    
    @ViewBuilder
    private func compactPlaceView(wrapper: GooglePlacesSearchPlaceWrapper) -> some View {
        HStack(spacing: 10) {
            if let photo = wrapper.place?.photos?.first {
                WebImage(url: photo.buildUrl()) { view in
                    view.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.1)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                    Image(systemName: "photo")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray.opacity(0.3))
                }
                .frame(width: 44, height: 44)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(wrapper.place?.displayName?.text ?? "不明なスポット")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black.opacity(0.7))
                    .lineLimit(1)
                
                if let type = wrapper.place?.types?.first(where: { !$0.contains("point_of_interest") && !$0.contains("establishment") }) {
                    Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.gray)
                }
            }
            .frame(maxWidth: 150, alignment: .leading)
        }
        .padding(8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
    
    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "不明" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
