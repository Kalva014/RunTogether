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
    
    // Check if a specific user has seen onboarding
    func hasSeenOnboarding(for userId: String?) -> Bool {
        guard let userId = userId else { return false }
        let key = "\(hasSeenOnboardingKey)_\(userId)"
        return userDefaults.bool(forKey: key)
    }
    
    // Mark onboarding as complete for a specific user
    func markOnboardingComplete(for userId: String?) {
        guard let userId = userId else { return }
        let key = "\(hasSeenOnboardingKey)_\(userId)"
        userDefaults.set(true, forKey: key)
        print("✅ Marked onboarding complete for user: \(userId)")
    }
    
    // Reset onboarding for a specific user (useful for testing)
    func resetOnboarding(for userId: String?) {
        guard let userId = userId else { return }
        let key = "\(hasSeenOnboardingKey)_\(userId)"
        userDefaults.set(false, forKey: key)
        print("🔄 Reset onboarding for user: \(userId)")
    }
    
    // Legacy support - global onboarding check (deprecated)
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
