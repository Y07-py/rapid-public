//
//  RapidApp.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/06.
//

import SwiftUI
import RevenueCat

@main
struct RapidApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var coreDataStack = CoreDataStack.shared
    
    init() {
        let revenuCatAPIKey = Bundle.main.object(forInfoDictionaryKey: "REVENUE_CAT_API_KEY") as! String
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: revenuCatAPIKey)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.persistentContainer.viewContext)
        }
    }
}
