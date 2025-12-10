//
//  AppDelegate.swift
//  RunTogether
//
//  Production-ready app delegate with orientation lock and RevenueCat
//

import UIKit
import RevenueCat

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // Force portrait orientation only
        return .portrait
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure RevenueCat with API key from Info.plist
        guard let revenueCatKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCat API Key") as? String,
              !revenueCatKey.isEmpty,
              revenueCatKey != "$(REVENUECAT_KEY)" else {
            fatalError("❌ RevenueCat API Key not found in Info.plist. Please set REVENUECAT_KEY in Build Settings.")
        }
        
        SubscriptionManager.shared.configure(apiKey: revenueCatKey)
        
        // Disable idle timer to prevent screen from dimming during runs
        // This is important for the running view
        return true
    }
}
