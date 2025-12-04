//
//  SafetyTipsManager.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 12/4/25.
//

import Foundation

class SafetyTipsManager: ObservableObject {
    static let shared = SafetyTipsManager()
    
    @Published var currentTip: SafetyTip?
    
    private let tips: [SafetyTip] = [
        SafetyTip(
            icon: "eye.fill",
            message: "Stay aware of your surroundings at all times"
        ),
        SafetyTip(
            icon: "car.fill",
            message: "Don't interact with the app while crossing streets"
        ),
        SafetyTip(
            icon: "figure.run",
            message: "Listen to your body and stop if you feel pain or discomfort"
        ),
        SafetyTip(
            icon: "drop.fill",
            message: "Stay hydrated before, during, and after your run"
        ),
        SafetyTip(
            icon: "flame.fill",
            message: "Always warm up before running and cool down afterward"
        ),
        SafetyTip(
            icon: "moon.stars.fill",
            message: "Wear reflective gear when running in low-light conditions"
        ),
        SafetyTip(
            icon: "figure.walk",
            message: "Use treadmills according to manufacturer instructions"
        ),
        SafetyTip(
            icon: "exclamationmark.triangle.fill",
            message: "Avoid running in extreme weather conditions"
        ),
        SafetyTip(
            icon: "heart.fill",
            message: "Know your limits and don't push beyond your fitness level"
        ),
        SafetyTip(
            icon: "phone.fill",
            message: "Carry identification and emergency contact information"
        ),
        SafetyTip(
            icon: "figure.2.and.child.holdinghands",
            message: "Let someone know your running route and expected return time"
        ),
        SafetyTip(
            icon: "speaker.wave.2.fill",
            message: "Keep volume low or use one earbud to hear your surroundings"
        )
    ]
    
    private var lastTipIndex = -1
    private let userDefaults = UserDefaults.standard
    private let hasSeenSafetyDisclaimerKey = "hasSeenSafetyDisclaimer"
    private let hasSeenPreRunChecklistKey = "hasSeenPreRunChecklist"
    
    private init() {}
    
    // Get a random tip that's different from the last one shown
    func getRandomTip() -> SafetyTip {
        var newIndex: Int
        repeat {
            newIndex = Int.random(in: 0..<tips.count)
        } while newIndex == lastTipIndex && tips.count > 1
        
        lastTipIndex = newIndex
        return tips[newIndex]
    }
    
    // Show a tip and automatically dismiss after duration
    func showTip(duration: TimeInterval = 5.0) {
        currentTip = getRandomTip()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.currentTip = nil
        }
    }
    
    // Dismiss current tip
    func dismissTip() {
        currentTip = nil
    }
    
    // Check if user has seen safety disclaimer
    func hasSeenSafetyDisclaimer(for userId: String?) -> Bool {
        guard let userId = userId else { return false }
        let key = "\(hasSeenSafetyDisclaimerKey)_\(userId)"
        return userDefaults.bool(forKey: key)
    }
    
    // Mark safety disclaimer as seen
    func markSafetyDisclaimerSeen(for userId: String?) {
        guard let userId = userId else { return }
        let key = "\(hasSeenSafetyDisclaimerKey)_\(userId)"
        userDefaults.set(true, forKey: key)
        print("✅ Marked safety disclaimer as seen for user: \(userId)")
    }
    
    // Check if user has seen pre-run checklist
    func hasSeenPreRunChecklist(for userId: String?) -> Bool {
        guard let userId = userId else { return false }
        let key = "\(hasSeenPreRunChecklistKey)_\(userId)"
        return userDefaults.bool(forKey: key)
    }
    
    // Mark pre-run checklist as seen
    func markPreRunChecklistSeen(for userId: String?) {
        guard let userId = userId else { return }
        let key = "\(hasSeenPreRunChecklistKey)_\(userId)"
        userDefaults.set(true, forKey: key)
        print("✅ Marked pre-run checklist as seen for user: \(userId)")
    }
    
    // Reset for testing
    func resetSafetyFlags(for userId: String?) {
        guard let userId = userId else { return }
        userDefaults.set(false, forKey: "\(hasSeenSafetyDisclaimerKey)_\(userId)")
        userDefaults.set(false, forKey: "\(hasSeenPreRunChecklistKey)_\(userId)")
        print("🔄 Reset safety flags for user: \(userId)")
    }
}

struct SafetyTip: Identifiable {
    let id = UUID()
    let icon: String
    let message: String
}
