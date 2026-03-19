//
//  LegalTermsView.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/05.
//

import SwiftUI

struct LegalTermsView: View {
    @Binding var isShowWindow: Bool
    @State private var selectedTab: LegalTab = .terms
    
    @Namespace private var namespace
    
    enum LegalTab: String, CaseIterable {
        case terms = "利用規約"
        case privacy = "プライバシー"
    }
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            // Decorative background glow
            VStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: 120, y: -100)
                Spacer()
                Circle()
                    .fill(Color.selectedColor.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: -120, y: 100)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content Picker
                segmentedControl
                    .padding(.horizontal, 22)
                    .padding(.bottom, 15)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 25) {
                        if selectedTab == .terms {
                            termsOfServiceContent
                        } else {
                            privacyPolicyContent
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                isShowWindow = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color.secondaryBackgroundColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            
            Text(selectedTab.rawValue)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
                .padding(.leading, 10)
            
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 15)
    }
    
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(LegalTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundStyle(selectedTab == tab ? Color.selectedColor : .gray)
                        
                        if selectedTab == tab {
                            Rectangle()
                                .fill(Color.selectedColor)
                                .frame(height: 3)
                                .clipShape(Capsule())
                                .matchedGeometryEffect(id: "selectedHeader", in: namespace)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 3)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .background {
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 1)
            }
        }
    }
    
    @ViewBuilder
    private var termsOfServiceContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("本利用規約（以下「本規約」といいます。）は、Rapid（以下「本アプリ」といいます。）の提供するサービス（以下「本サービス」といいます。）の利用条件を定めるものです。登録利用者の皆様（以下「ユーザー」といいます。）には、本規約に従って本サービスをご利用いただきます。")
                .lineSpacing(6)
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.7))
            
            sectionView(title: "第1条（適用）", content: "本規約は、ユーザーと当運営との間の本サービスの利用に関わる一切の関係に適用されるものとします。")
            
            sectionView(title: "第2条（利用登録・資格）", bullets: [
                "本サービスは、18歳以上（高校生を除く）の方のみが利用できるものとします。",
                "ユーザーは、登録にあたり公的身分証明書による年齢確認を行うものとします。",
                "既婚者、または交際相手がいる方は本サービスを利用できません。",
                "当運営は、以下の事由があると判断した場合、利用登録の申請を承認しないことがあり、その理由については一切の開示義務を負わないものとします。",
                "  ・登録申請に際して虚偽の事項を届け出た場合",
                "  ・本規約に違反したことがある者からの申請である場合",
                "  ・その他、当運営が利用登録を相当でないと判断した場合"
            ])
            
            sectionView(title: "第3条（認証情報および外部アカウントの管理）", bullets: [
                "ユーザーは、自己の責任において、本サービスの利用に用いる認証情報（メールアドレス、SMS認証コード、または本サービスと連携させた外部サービスのアカウント等）を適切に管理するものとします。",
                "ユーザーは、いかなる場合にも、前項の認証情報および外部サービスのアカウントを第三者に譲渡または貸与することはできません。",
                "認証情報の管理不十分、使用上の過誤、第三者の使用等によって生じた損害の責任はユーザーが負うものとし、当運営は一切の責任を負いません。"
            ])
            
            sectionView(title: "第4条（禁止事項）", content: "ユーザーは、本サービスの利用にあたり、以下の行為をしてはなりません。", bullets: [
                "法令または公序良俗に違反する行為",
                "犯罪行為に関連する行為",
                "他のユーザーに対するハラスメント、ストーカー行為、誹謗中傷",
                "ボイスチャット内容の無断録音、およびSNS等への公開・転載",
                "性的な内容を含む言動、またはわいセツな行為を目的とする行為",
                "営利目的の勧誘、宗教活動、政治活動",
                "本アプリ外での出会いを強要する行為、または一方的に個人情報を聞き出す行為",
                "その他、当運営が不適切と判断する行為"
            ])
            
            sectionView(title: "第5条（本サービスの提供の停止等）", content: "当運営は、以下のいずれかの事由があると判断した場合、ユーザーに事前に通知することなく本サービスの全部または一部の提供を停止または中断することができるものとします。", bullets: [
                "本サービスにかかるコンピュータシステムの保守点検または更新を行う場合",
                "地震、落雷、火災、停電または天災などの不可抗力により、本サービスの提供が困難となった場合",
                "その他、当運営が本サービスの提供が困難と判断した場合"
            ])
            
            sectionView(title: "第6条（利用制限および登録抹消）", content: "当運営は、ユーザーが本規約のいずれかの条項に違反した場合、事前の通知なく、ユーザーに対して本サービスの全部もしくは一部の利用を制限し、またはユーザーとしての登録を抹消することができるものとします。")
            
            sectionView(title: "第7条（有料サービス・決済）", bullets: [
                "ユーザーは、本サービスの有料コンテンツを利用する場合、当運営が定める利用料金を支払うものとする。",
                "利用料金の支払方法は、Apple Inc.またはGoogle Inc.等の決済プラットフォームが定める方法に寄ります。",
                "一度支払われた利用料金は、法令に定める場合を除き、理由の如何を問わず返還することはできません。"
            ])
            
            sectionView(title: "第8条（免責事項）", bullets: [
                "当運営は、ユーザー間の交流において生じたトラブル（事件、事故、金銭的紛争等）について、一切の責任を負いません。",
                "本サービスは、特定の相手との交際や結婚を保証するものではありません。"
            ])
            
            sectionView(title: "第10条（規約の変更）", content: "当運営は、必要と判断した場合には、ユーザーに通知することなくいつでも本規約を変更することができるものとします。")
            
            sectionView(title: "第11条（準拠法・裁判管轄）", bullets: [
                "本規約の解釈にあたっては、日本法を準拠法とします。",
                "本サービスに関して紛争が生じた場合には、当運営の所在地を管轄する裁判所を専属的合意管轄とします。"
            ])
        }
    }
    
    @ViewBuilder
    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Rapid（以下、「本アプリ」といいます。）を運営する当方（以下、「当方」といいます。）は、ユーザーの皆様（以下、「ユーザー」といいます。）の個人情報の保護を極めて重要なものと認識し、以下の通りプライバシーポリシー（以下、「本ポリシー」といいます。）を定めます。")
                .lineSpacing(6)
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.7))
            
            sectionView(title: "1. 取得する個人情報", content: "当方は、本アプリの提供にあたり、以下の情報を取得します。", bullets: [
                "プロフィール情報: 氏名（ニックネーム）、生年月日、性別、居住地、職業、学歴、趣味、自己紹介文、写真、動画等",
                "本人確認情報: 公的証明書（運転免許証、パスポート、健康保険証等）の画像データ、およびこれらに記載された情報",
                "連絡先情報: メールアドレス、電話番号、SNSアカウント連携情報等",
                "位置情報: ユーザーの同意に基づき、端末から送信されるGPS情報",
                "決済情報: クレジットカード情報、アプリ内課金履歴",
                "利用状況に関する情報: 本アプリ内での活動履歴、メッセージの送受信履歴、アクセスログ、Cookie、端末情報等"
            ])
            
            sectionView(title: "2. 利用目的", content: "当方は、取得した個人情報を以下の目的で利用します。", bullets: [
                "本アプリの提供・マッチングの実現",
                "本人確認および安全性の確保",
                "サービスの維持・改善",
                "カスタマーサポート",
                "マーケティング・広告"
            ])
            
            sectionView(title: "3. 個人情報の第三者提供", content: "当方は、法令に基づく場合を除き、ユーザーの同意を得ることなく、個人情報を第三者に提供することはありません。ただし、以下の場合は除きます。", bullets: [
                "利用目的の達成に必要な範囲内で、業務委託先に委託する場合",
                "合併、会社分割、営業譲渡その他の事由によって事業の承継が行われる場合"
            ])
            
            sectionView(title: "4. 安全管理措置", content: "当方は、個人情報の漏洩、滅失または毀損の防止その他の個人情報の安全管理のために、適切な組織的、人的、物理的、および技術的措置を講じます。")
            
            sectionView(title: "5. ユーザーの権利", content: "ユーザーは、当方に対し、自身の個人情報の開示、訂正、追加、削除、または利用の停止を請求することができます。")
            
            sectionView(title: "6. 位置情報の取り扱い", content: "位置情報の取得は、ユーザーが端末の設定または本アプリの設定で許可した場合にのみ行われます。")
            
            sectionView(title: "7. メッセージの内容について", content: "当方は、本アプリの安全な利用環境を維持するため、利用規約に基づき、ユーザー間のメッセージ内容を確認（自動フィルタリングを含む）する場合があります。")
            
            sectionView(title: "8. 本ポリシーの変更", content: "当方は、法令の改正やサービス内容の変更に伴い、本ポリシーを随時変更することがあります。")
        }
    }
    
    @ViewBuilder
    private func sectionView(title: String, content: String? = nil, bullets: [String]? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.selectedColor)
            
            if let content = content {
                Text(content)
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.8))
                    .lineSpacing(5)
            }
            
            if let bullets = bullets {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Text("・")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.selectedColor)
                            Text(bullet)
                                .font(.system(size: 14))
                                .foregroundStyle(.black.opacity(0.8))
                                .lineSpacing(4)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondaryBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    LegalTermsView(isShowWindow: .constant(true))
}
