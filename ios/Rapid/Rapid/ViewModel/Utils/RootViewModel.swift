//
//  RootViewModel.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/08.
//

import Foundation
import SwiftUI
import Combine

class RootViewModel<Root: Equatable>: ObservableObject {
    var roots: [Root] = [Root]()
    
    var onPush: ((Root) -> Void)?
    var onPop: ((Int) -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    
    init(root: Root) {
        roots.append(root)
    }
    
    func push(_ root: Root) {
        roots.append(root)
        onPush?(root)
    }
    
    func pop(_ cnt: Int) {
        roots.removeLast(cnt)
        onPop?(cnt)
    }
    
//    private func setUpNotificationPublisherToPush() {
//        NotificationCenter.default
//            .publisher(for: .pushRootViewNotification)
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] notification in
//                guard let self = self else { return }
//                if let root = notification.userInfo?["root"] as? Root,
//                   type(of: root) == Root.self {
//                    self.push(root)
//                }
//            }
//            .store(in: &cancellables)
//    }
//    
//    private func setUpNotificationPublisherToPop() {
//        NotificationCenter.default
//            .publisher(for: .popRootViewNotification)
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] notification in
//                guard let self = self else { return }
//                if let root = notification.userInfo?["root"] as? Root,
//                   let cnt = notification.userInfo?["cnt"] as? Int {
//                    if type(of: root) == Root.self {
//                        self.pop(cnt)
//                    }
//                }
//            }
//            .store(in: &cancellables)
//    }
//    
}
