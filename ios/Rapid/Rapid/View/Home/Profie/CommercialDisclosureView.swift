//
//  CommercialDisclosureView.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/10.
//

import SwiftUI

struct CommercialDisclosureView: View {
    @Binding var isShowWindow: Bool
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.backgroundColor.ignoresSafeArea()
            
            // Decorative background glow
            VStack {
                Circle()
                    .fill(Color.mainColor.opacity(0.12))
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
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 25) {
                        
                        // Intro Text
                        VStack(alignment: .leading, spacing: 12) {
                            Text("特定商取引法に基づく表記")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.black.opacity(0.8))
                            
                            Text("アプリ「Rapid」における有料サービス（定期購読・ポイント購入等）の提供にあたり、特定商取引法に基づき以下の通り表示いたします。")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.black.opacity(0.6))
                                .lineSpacing(6)
                        }
                        .padding(.horizontal, 5)
                        
                        // Disclosure Table
                        VStack(spacing: 1) {
                            disclosureRow(label: "サービス名", value: "Rapid")
                            disclosureRow(label: "販売業者", value: "木本瑛介")
                            disclosureRow(label: "運営責任者", value: "木本瑛介")
                            disclosureRow(label: "所在地", value: "〒150-0043\n東京都渋谷区道玄坂1丁目10番8号\n渋谷道玄坂東急ビル2F−C")
                            disclosureRow(label: "電話番号", value: "050-8887-4804")
                            disclosureRow(label: "販売価格", value: "購入手続きの際に画面に表示されます。")
                            disclosureRow(label: "商品代金以外の必要費用", value: "サービスを利用するためのインターネット接続料金、パケット通信料金等の通信費用はお客様のご負担となります。")
                            disclosureRow(label: "お支払方法", value: "・Apple ID決済（App Store経由）")
                            disclosureRow(label: "代金の支払時期", value: "Appleが定める規約及び引落日に基づきます。")
                            disclosureRow(label: "サービスの利用可能時期", value: "お支払い手続き完了後、システム上の処理が完了次第、直ちにご利用いただけます。")
                            disclosureRow(label: "返品・返金・キャンセル", value: "デジタルコンテンツ及びサービスの性質上、購入確定後のお客様都合による返品・交換・キャンセル・返金には応じられません。\n\n※アプリを削除（アンインストール）しても定期購読は解約されませんのでご注意ください。")
                            disclosureRow(label: "解約・退会について", value: "アプリ内の「設定」＞「退会」よりいつでも退会手続きが可能です。\n\n定期購読（サブスクリプション）の解約は、次回更新日の24時間前までに、お客様ご自身で各プラットフォーム（App Store / Google Play等）の設定画面から自動更新の停止を行ってください。\n\n月の途中で解約・退会した場合も、日割りによる返金はいたしません。")
                            disclosureRow(label: "動作環境", value: "iOS 17.0 以上\n（最新の動作環境はAppストアのダウンロードページをご確認ください）")
                            disclosureRow(label: "許認可等", value: "インターネット異性紹介事業 届出済み\n受理番号：[発行待ち]")
                        }
                        .background(Color.secondaryBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
                        
                        // Note Footer
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "hand.shield.fill")
                                    .foregroundStyle(Color.selectedColor)
                                
                                Text("付記")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.8))
                            }
                            
                            Text("「Rapid」は、安心・安全な出会いを提供するため、公的証明書による本人確認を実施しております。利用規約を遵守の上、ご利用ください。")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.gray)
                                .lineSpacing(5)
                        }
                        .padding(20)
                        .background(Color.secondaryBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    .padding(.bottom, 50)
                }
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Button(action: {
                withAnimation(.spring()) {
                    isShowWindow = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(Color.secondaryBackgroundColor)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("特定商取引法に基づく表記")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 15)
    }
    
    @ViewBuilder
    private func disclosureRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.selectedColor.opacity(0.8))
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black.opacity(0.7))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
                .padding(.top, 10)
                .opacity(0.3)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
    }
}

#Preview {
    CommercialDisclosureView(isShowWindow: .constant(true))
}
