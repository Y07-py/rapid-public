//
//  CommunityGuidelineView.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/04.
//

import SwiftUI

struct CommunityGuidelineView: View {
    @Binding var isShowWindow: Bool
    
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
                // Custom Header
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
                    
                    Text("コミュニティガイドライン")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                        .padding(.leading, 10)
                    
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 15)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        // 1. 概要
                        VStack(alignment: .leading, spacing: 15) {
                            Text("1. 概要")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.selectedColor)
                            
                            Text("本アプリは、特定の場所や共通の目的を通じて、健全かつ誠実な出会いを提供することを目的としています。\nすべてのユーザーが安心してサービスを利用できるよう、私たちは安全でリスペクトに満ちたコミュニティを維持することに全力を尽くしています。")
                                .lineSpacing(6)
                            
                            Text("本ガイドラインは、ユーザーの皆様に守っていただきたい「共通のルール」です。アプリを利用することで、本ガイドラインに同意したものとみなされます。これらに反する行為が確認された場合、投稿の削除やアカウントの停止（強制退会）などの措置をとることがあります。")
                                .lineSpacing(6)
                        }
                        .padding(20)
                        .background(Color.secondaryBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        // 2. ガイドラインの詳細
                        VStack(alignment: .leading, spacing: 20) {
                            Text("2. ガイドラインの詳細")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.selectedColor)
                            
                            Group {
                                guidelineItem(
                                    title: "2.1 ビジネス利用・関連情報の持ち込み禁止",
                                    content: "本アプリは、個人的な出会いや交流を目的としたプラットフォームです。コミュニティ内へのビジネス関連の話題の持ち込みは一切禁止します。",
                                    bullets: [
                                        "営業・宣伝活動: 自身の事業やサービスの宣伝、セミナー、副業、投資、キャリア相談を装った営業活動。",
                                        "ネットワークビジネス: MLM（マルチレベルマーケティング）や組織への勧誘。",
                                        "求人・採用: 従業員やパートナーの募集行為。"
                                    ]
                                )
                                
                                guidelineItem(
                                    title: "2.2 性的な不適切行為の禁止",
                                    content: "公序良俗に反するわいせつな行為や、相手に不快感を与える性的な表現を禁止します。",
                                    bullets: [
                                        "不適切な投稿: 露出の多い画像、性的な内容を想起させるプロフィール文やメッセージの送信。",
                                        "アダルト・性風俗: 性的なサービスの提供、売春・買春、パパ活・ママ活などの示唆。",
                                        "性的嫌がらせ: 相手が望まない性的な言動や、執拗なアプローチ。"
                                    ]
                                )
                                
                                guidelineItem(
                                    title: "2.3 業者・勧誘・詐欺行為の禁止",
                                    content: "他者の利益を不当に奪う行為や、アプリ外のサービスへ不当に誘導する行為を禁止します。",
                                    bullets: [
                                        "詐欺行為: 金銭の要求、偽の投資話、フィッシングサイトへの誘導。",
                                        "業者利用: 組織的なサクラ行為や、他サイト・他アプリへの執拗な誘導。",
                                        "なりすまし: 実在する著名人や他人の写真・情報を用いたアカウント作成。"
                                    ]
                                )
                                
                                guidelineItem(
                                    title: "2.4 暴力・誹謗中傷・嫌がらせの禁止",
                                    content: "すべてのユーザーが平等にリスペクトされる環境を守るため、攻撃的な行為を禁止します。",
                                    bullets: [
                                        "誹謗中傷: 相手の容姿、性格、国籍、性別、信仰などを攻撃する言動。",
                                        "脅迫・暴力: 身体的な危害を予告する言動、または実際に暴力を振るう行為。",
                                        "晒し行為: 相手の個人情報ややり取りのスクリーンショットを、本人の許可なくSNS等に公開する行為。"
                                    ]
                                )
                                
                                guidelineItem(
                                    title: "2.5 虚偽・不正利用の禁止",
                                    content: "システムの健全性を損なう不正な操作や情報の偽装を禁止します。",
                                    bullets: [
                                        "複数アカウントの併用: 1人のユーザーが複数のアカウントを所持・運用すること。",
                                        "情報の偽装: 年齢、性別、居住地などのプロフィール項目における虚偽の登録。",
                                        "不正アクセス: アプリの脆弱性を突いた攻撃や、他人のアカウントへの不正ログイン。"
                                    ]
                                )
                                
                                guidelineItem(
                                    title: "2.6 法令遵守",
                                    content: "日本国内の法律および条例を遵守して利用してください。",
                                    bullets: [
                                        "18歳未満の利用禁止: 18歳未満（および高校生）の利用は法律により禁じられています。",
                                        "違法行為の禁止: 薬物売買、賭博、児童ポルノの配布など、あらゆる犯罪行為。",
                                        "条例の遵守: 待ち合わせ場所における公共のルールや、迷惑防止条例に反する行為。"
                                    ]
                                )
                            }
                        }
                        .padding(20)
                        .background(Color.secondaryBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        // 3. 違反への対応
                        VStack(alignment: .leading, spacing: 15) {
                            Text("3. 違反への対応")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.selectedColor)
                            
                            Text("ガイドラインに違反する行為を発見した場合は、アプリ内の「報告機能」からお知らせください。運営チームは報告内容を確認し、以下を含む適切な処置を迅速に行います。")
                                .lineSpacing(6)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                bulletPoint("警告: 軽微な違反に対する注意喚起。")
                                bulletPoint("コンテンツ削除: ガイドラインに抵触する投稿や写真の削除。")
                                bulletPoint("利用停止: 一定期間、または無期限のアカウント凍結。")
                                bulletPoint("法的措置: 悪質な詐欺や脅迫、事件性が高いと判断された場合。")
                            }
                        }
                        .padding(20)
                        .background(Color.secondaryBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        Text("私たちは、誠実な出会いを探すすべてのユーザーを全力で守ります。")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    @ViewBuilder
    private func guidelineItem(title: String, content: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black.opacity(0.9))
            
            Text(content)
                .lineSpacing(5)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(bullets, id: \.self) { bullet in
                    bulletPoint(bullet)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.selectedColor)
            Text(text)
                .lineSpacing(4)
        }
    }
}

#Preview {
    CommunityGuidelineView(isShowWindow: .constant(true))
}
