//
//  ChatRoomReportReasonView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/13.
//

import Foundation
import SwiftUI

struct ChatRoomReportReasonView: View {
    @EnvironmentObject private var chatRoomViewModel: ChatRoomViewModel
    @EnvironmentObject private var chatRoomRootViewModel: RootViewModel<ChatRoomRoot>
    
    var body: some View {
        ZStack {
            Color.secondaryBackgroundColor.ignoresSafeArea()
            VStack(alignment: .center, spacing: .zero) {
                
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
