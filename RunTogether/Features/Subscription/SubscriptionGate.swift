//
//  SubscriptionGate.swift
//  RunTogether
//
//  Feature access control and subscription gate
//

import SwiftUI

/// View modifier to gate features behind subscription
struct SubscriptionGate: ViewModifier {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    
    let requiredTier: SubscriptionTier
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if subscriptionManager.hasAccess(to: requiredTier) {
                    action()
                } else {
                    showPaywall = true
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView {
                    // After successful subscription, perform the action
                    if subscriptionManager.hasAccess(to: requiredTier) {
                        action()
                    }
                }
            }
    }
}

extension View {
    /// Gate a feature behind a subscription
    /// - Parameters:
    ///   - tier: Required subscription tier
    ///   - action: Action to perform if user has access
    func requiresSubscription(tier: SubscriptionTier = .weekly, action: @escaping () -> Void) -> some View {
        self.modifier(SubscriptionGate(requiredTier: tier, action: action))
    }
}

/// Wrapper view to conditionally show content based on subscription
struct SubscriptionContent<Content: View, Fallback: View>: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    let requiredTier: SubscriptionTier
    let content: Content
    let fallback: Fallback
    
    init(
        requiredTier: SubscriptionTier = .weekly,
        @ViewBuilder content: () -> Content,
        @ViewBuilder fallback: () -> Fallback
    ) {
        self.requiredTier = requiredTier
        self.content = content()
        self.fallback = fallback()
    }
    
    var body: some View {
        Group {
            if subscriptionManager.hasAccess(to: requiredTier) {
                content
            } else {
                fallback
            }
        }
    }
}

/// Premium badge to show on locked features
struct PremiumBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.caption2)
            Text("PREMIUM")
                .font(.caption2.bold())
        }
        .foregroundColor(.black)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(6)
    }
}

/// Overlay to show on locked features
struct LockedFeatureOverlay: View {
    @State private var showPaywall = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text("Premium Feature")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Upgrade to unlock")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Button(action: {
                    showPaywall = true
                }) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Upgrade")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Usage Examples

/*
 
 // Example 1: Gate a button action
 Button("Start Multiplayer Race") {
     // This will only execute if user has subscription
 }
 .requiresSubscription(tier: .weekly) {
     startMultiplayerRace()
 }
 
 // Example 2: Conditionally show content
 SubscriptionContent(requiredTier: .weekly) {
     // Premium content
     AdvancedAnalyticsView()
 } fallback: {
     // Free tier content
     BasicAnalyticsView()
 }
 
 // Example 3: Show premium badge
 HStack {
     Text("Advanced Stats")
     if !subscriptionManager.hasPremiumAccess() {
         PremiumBadge()
     }
 }
 
 // Example 4: Lock a feature with overlay
 ZStack {
     AdvancedFeatureView()
     
     if !subscriptionManager.hasPremiumAccess() {
         LockedFeatureOverlay()
     }
 }
 
 */
