//
//  RootViewController.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/08.
//

import Foundation
import UIKit
import SwiftUI

enum RootChangeAnimationStyle {
    case horizontal
    case vertical
}

struct RootViewController<Root: Equatable, Screen: View>: UIViewControllerRepresentable {
    let rootViewModel: RootViewModel<Root>
    let hideBackButton: Bool
    let animated: Bool
    let animationStyle: RootChangeAnimationStyle
    
    @ViewBuilder
    let builder: (Root) -> Screen
    
    init(
        rootViewModel: RootViewModel<Root>,
        hideBackButton: Bool = false,
        animated: Bool = false,
        animationStyle: RootChangeAnimationStyle = .horizontal,
        @ViewBuilder builder: @escaping (Root) -> Screen
    ) {
        self.rootViewModel = rootViewModel
        self.hideBackButton = hideBackButton
        self.animated = animated
        self.animationStyle = animationStyle
        self.builder = builder
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let navigationController = UINavigationController()
        navigationController.delegate = context.coordinator
        
        navigationController.setNavigationBarHidden(hideBackButton, animated: animated)
        
        rootViewModel.roots.forEach { root in
            let hostingController = HostingController(rootView: builder(root))
            hostingController.navigationItem.setHidesBackButton(hideBackButton, animated: animated)
            navigationController.pushViewController(hostingController, animated: animated)
        }
        
        rootViewModel.onPush = { root in
            let hostingController = HostingController(rootView: builder(root))
            hostingController.navigationItem.setHidesBackButton(hideBackButton, animated: animated)
            navigationController.pushViewController(hostingController, animated: true)
        }
        
        rootViewModel.onPop = { cnt in
            let count = navigationController.viewControllers.count
            let targetIndex = max(count - cnt - 1, 0)
            if targetIndex < count {
                let targetVC = navigationController.viewControllers[targetIndex]
                navigationController.popToViewController(targetVC, animated: true)
            }
        }
        
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    
    class Coordinator: NSObject, UINavigationControllerDelegate {
        let parent: RootViewController
        
        init(_ parent: RootViewController) {
            self.parent = parent
        }
        
        func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
            switch parent.animationStyle {
            case .horizontal:
                return nil
            case .vertical:
                return SideDownanimator(operation: operation)
            }
        }
    }
    
    private class SideDownanimator: NSObject, UIViewControllerAnimatedTransitioning {
        let duration: TimeInterval = 0.3
        let operation: UINavigationController.Operation
        
        init(operation: UINavigationController.Operation) {
            self.operation = operation
            super.init()
        }
        
        func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
            return duration
        }
        
        func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
            let container = transitionContext.containerView
            let screenBounds = container.bounds
            
            guard let fromVC = transitionContext.viewController(forKey: .from),
                  let toVC = transitionContext.viewController(forKey: .to) else {
                transitionContext.completeTransition(false)
                return
            }
            
            if operation == .push {
                container.insertSubview(toVC.view, belowSubview: fromVC.view)
                toVC.view.frame = screenBounds
                
                UIView.animate(withDuration: duration, animations: {
                    fromVC.view.frame = screenBounds.offsetBy(dx: 0, dy: screenBounds.height)
                }) { finished in
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                }
            } else if operation == .pop {
                container.insertSubview(toVC.view, belowSubview: fromVC.view)
                toVC.view.frame = container.bounds.offsetBy(dx: 0, dy: container.bounds.height)
                
                UIView.animate(withDuration: duration, animations: {
                    toVC.view.frame = container.bounds
                }, completion: { finished in
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                })
            }
        }
    }
}
