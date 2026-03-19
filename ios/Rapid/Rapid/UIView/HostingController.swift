//
//  HostingController.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/08.
//

import Foundation
import UIKit
import SwiftUI

class HostingController<Content: View>: UIHostingController<Content> {
    var transitionDelegate: UIViewControllerTransitioningDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        self.edgesForExtendedLayout = .all
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.isNavigationBarHidden = true
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        additionalSafeAreaInsets.bottom = .zero
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        additionalSafeAreaInsets.bottom = .zero
    }
}
