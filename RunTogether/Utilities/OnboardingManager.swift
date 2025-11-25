//
//  OnboardingManager.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 11/25/25.
//  Manages onboarding state for first-time users
//

import Foundation

class OnboardingManager {
    static let shared = OnboardingManager()
    
    private let hasSeenOnboardingKey = "hasSeenOnboarding"
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    var hasSeenOnboarding: Bool {
        get {
            return userDefaults.bool(forKey: hasSeenOnboardingKey)
        }
        set {
            userDefaults.set(newValue, forKey: hasSeenOnboardingKey)
        }
    }
    
    func markOnboardingComplete() {
        hasSeenOnboarding = true
    }
    
    func resetOnboarding() {
        hasSeenOnboarding = false
    }
}
