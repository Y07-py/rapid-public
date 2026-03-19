//
//  HomeTabViewRepresentable.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/09/01.
//

import Foundation
import UIKit
import SwiftUI

struct TabDefinition {
    let title: String
    let systemImage: String
    let build: () -> AnyView
}

struct TabItem{
    let definition: TabDefinition
    init<Content: View>(title: String, systemImage: String, @ViewBuilder _ content: @escaping () -> Content) {
        self.definition = .init(
            title: title,
            systemImage: systemImage,
            build: {
                AnyView(content())
            }
        )
    }
}

@resultBuilder
enum TabsBuilder {
    static func buildBlock(_ components: TabItem...) -> [TabDefinition] {
        components.map { $0.definition }
    }

    public static func buildArray(_ components: [[TabDefinition]]) -> [TabDefinition] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [TabDefinition]?) -> [TabDefinition] {
        component ?? []
    }

    public static func buildEither(first: [TabDefinition]) -> [TabDefinition] { first }
    public static func buildEither(second: [TabDefinition]) -> [TabDefinition] { second }

    public static func buildLimitedAvailability(_ component: [TabDefinition]) -> [TabDefinition] {
        component
    }
}

public struct HomeTabViewRepresentable: UIViewControllerRepresentable {
    @Binding var selection: Int
    let nonNavigationIndices: Set<Int>
    let onTap: ((Int) -> Void)?
    
    private let tabs: [TabDefinition]
    
    init(
        selection: Binding<Int>,
        nonNavigationIndices: Set<Int> = [],
        onTap: ((Int) -> Void)? = nil,
        @TabsBuilder _ content: () -> [TabDefinition]
    ) {
        self._selection = selection
        self.nonNavigationIndices = nonNavigationIndices
        self.onTap = onTap
        self.tabs = content()
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIViewController(context: Context) -> UITabBarController {
        let tabBarController = UITabBarController()
        tabBarController.delegate = context.coordinator
        tabBarController.tabBar.backgroundColor = .init(hex: "F3F2EC")
        
        // Keep ui style in all os version.
        if #available(iOS 18.0, *) {
            tabBarController.mode = .tabBar
        }
        
        let viewController = tabs.enumerated().map { idx, tab -> UIViewController in
            let host = HostingController(rootView: tab.build())
            host.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.systemImage),
                selectedImage: nil
            )
            host.view.tag = idx
            return host
        }
        tabBarController.setViewControllers(viewController, animated: false)
        return tabBarController
    }
    
    public func updateUIViewController(_ uiViewController: UITabBarController, context: Context) {
        if uiViewController.selectedIndex != selection {
            uiViewController.selectedIndex = selection
        }
    }
    
    public final class Coordinator: NSObject, UITabBarControllerDelegate {
        let parent: HomeTabViewRepresentable
        
        init(_ parent: HomeTabViewRepresentable) {
            self.parent = parent
        }
        
        public func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            let targetIndex = viewController.view.tag
            
            if tabBarController.selectedIndex == targetIndex {
                return false
            }
            
            if parent.nonNavigationIndices.contains(targetIndex) {
                parent.onTap?(targetIndex)
                return false
            }
            
            return true
        }
        
        public func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            let idx = viewController.view.tag
            if parent.selection != idx {
                parent.selection = idx
            }
        }
    }
}
