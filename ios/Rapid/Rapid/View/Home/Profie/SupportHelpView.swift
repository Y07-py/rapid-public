//
//  SupportHelpView.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/10.
//

import SwiftUI

struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct SupportHelpView: View {
    @Binding var isShowWindow: Bool
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @State private var isShowInquiryForm: Bool = false
    @State private var searchText: String = ""
    
    // Sample FAQs
    private let faqs: [FAQItem] = [
        FAQItem(question: "本人確認にはどのくらい時間がかかりますか？", answer: "通常、申請から24時間以内に審査が完了いたします。込み合っている場合は最大3営業日ほどいただく場合がございます。"),
        FAQItem(question: "退会方法を教えてください。", answer: "「設定」＞「アカウント」＞「退会」よりお手続きいただけます。サブスクリプションに加入している場合は、App Storeの設定から自動更新を停止する必要があります。"),
        FAQItem(question: "メッセージの送信ができません。", answer: "お相手とのマッチングが成立しているかご確認ください。また、公的証明書による本人確認が完了していない場合はメッセージ送信が制限されることがあります。"),
        FAQItem(question: "ポイントの有効期限はありますか？", answer: "購入されたポイントの有効期限は、購入日から180日間となります。キャンペーン等で配布された無料ポイントは期限が異なる場合があります。")
    ]
    
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
                    .offset(x: 150, y: -100)
                Spacer()
                Circle()
                    .fill(Color.selectedColor.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: -150, y: 100)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 30) {
                        
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.gray)
                            TextField("キーワードで検索", text: $searchText)
                                .font(.system(size: 15))
                        }
                        .padding()
                        .background(Color.secondaryBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 25)
                        
                        // Contact Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("解決しない場合はこちら")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black.opacity(0.5))
                                .padding(.leading, 5)
                            
                            Button(action: {
                                withAnimation {
                                    self.isShowInquiryForm = true
                                }
                            }) {
                                HStack(spacing: 15) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.mainColor.opacity(0.1))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "envelope.fill")
                                            .foregroundStyle(Color.mainColor)
                                            .font(.system(size: 20))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("運営にお問い合わせ")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.black.opacity(0.8))
                                        Text("24時間以内に返信いたします")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.gray.opacity(0.3))
                                }
                                .padding(20)
                                .background(Color.secondaryBackgroundColor)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 25)
                        
                        // FAQ Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("よくあるご質問")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black.opacity(0.5))
                                .padding(.leading, 5)
                            
                            VStack(spacing: 0) {
                                ForEach(faqs) { faq in
                                    DisclosureGroup {
                                        Text(faq.answer)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.black.opacity(0.6))
                                            .lineSpacing(6)
                                            .padding(.top, 10)
                                            .padding(.bottom, 15)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } label: {
                                        Text(faq.question)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.black.opacity(0.8))
                                            .padding(.vertical, 15)
                                    }
                                    .accentColor(Color.selectedColor)
                                    
                                    if faq.id != faqs.last?.id {
                                        Divider().opacity(0.5)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .background(Color.secondaryBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, 25)
                        
                        // Safety Note
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(Color.selectedColor)
                            Text("Rapidでは、安全にご利用いただくために24時間体制で監視を行っております。不審なユーザーを見かけた場合は通報機能をご利用ください。")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.gray)
                        }
                        .padding(20)
                        .background(Color.secondaryBackgroundColor.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 25)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 50)
                }
            }
        }
        .sheet(isPresented: $isShowInquiryForm) {
            InquiryFormView(isPresented: $isShowInquiryForm)
                .environmentObject(profileViewModel)
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
            
            Text("お問い合わせ・ヘルプ")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 15)
    }
}

#Preview {
    SupportHelpView(isShowWindow: .constant(true))
}

fileprivate struct InquiryFormView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @Binding var isPresented: Bool
    @State private var message: String = ""
    @State private var inquiryType: String = "機能について"
    @State private var isLoading: Bool = false
    @State private var isShowAlert: Bool = false
    @State private var alertMessage: String = ""
    
    let inquiryTypes = ["機能について", "不具合の報告", "お支払いについて", "退会について", "その他"]
    
    @FocusState private var focus: Bool
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        // Inquiry Type
                        VStack(alignment: .leading, spacing: 12) {
                            Text("お問い合わせ種別")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.gray)
                            
                            Menu {
                                Picker("", selection: $inquiryType) {
                                    ForEach(inquiryTypes, id: \.self) { type in
                                        Text(type).tag(type)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(inquiryType)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.black.opacity(0.8))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.gray)
                                }
                                .padding()
                                .background(Color.secondaryBackgroundColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        // Message Input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("メッセージ")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.gray)
                            
                            TextEditor(text: $message)
                                .focused($focus)
                                .font(.system(size: 16))
                                .frame(minHeight: 200)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .background(Color.secondaryBackgroundColor)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                )
                            
                            Text("具体的な状況や、発生した日時などをご記入ください。")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray.opacity(0.8))
                        }
                        
                        Spacer()
                    }
                    .padding(25)
                }
                
                // Submit Button
                Button(action: {
                    submitInquiry()
                }) {
                    Text("送信する")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color.mainColor)
                        .clipShape(Capsule())
                        .shadow(color: Color.mainColor.opacity(0.2), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 30)
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            
            if isLoading {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    VStack(spacing: 15) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("送信中...")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .alert(isPresented: $isShowAlert) {
            Alert(
                title: Text("お問い合わせ"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("送信されました") {
                        isPresented = false
                    }
                }
            )
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.focus = false
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Button("キャンセル") {
                withAnimation {
                    isPresented = false
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color.selectedColor)
            
            Spacer()
            
            Text("お問い合わせ入力")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
            
            Spacer()
            
            Button("送信") {
                submitInquiry()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? .gray : Color.selectedColor)
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 15)
        .background(Color.backgroundColor)
    }
    
    private func submitInquiry() {
        isLoading = true
        profileViewModel.postInquiryMessage(type: inquiryType, message: message) { success in
            isLoading = false
            if success {
                alertMessage = "お問い合わせ内容が送信されました。運営にて内容を確認し、順次回答させていただきます。"
            } else {
                alertMessage = "通信エラーが発生しました。時間をおいて再度お試しください。"
            }
            isShowAlert = true
        }
    }
}
