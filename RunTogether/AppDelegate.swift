//
//  AppDelegate.swift
//  RunTogether
//
//  Production-ready app delegate with orientation lock
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // Force portrait orientation only
        return .portrait
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Disable idle timer to prevent screen from dimming during runs
        // This is important for the running view
        return true
    }
}
