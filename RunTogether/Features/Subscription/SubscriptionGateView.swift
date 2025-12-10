//
//  SubscriptionGateView.swift
//  RunTogether
//
//  Hard paywall that enforces subscription to access the app
//

import SwiftUI

struct SubscriptionGateView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isCheckingSubscription = true
    @State private var showPaywall = false
    
    let onAccessGranted: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isCheckingSubscription {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.orange)
                    
                    Text("Checking subscription...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                // Show paywall if no subscription
                if !subscriptionManager.isSubscribed {
                    PaywallView(onSubscribe: {
                        // After successful subscription, grant access
                        onAccessGranted()
                    })
                } else {
                    // User has active subscription, grant access immediately
                    Color.clear
                        .onAppear {
                            onAccessGranted()
                        }
                }
            }
        }
        .task {
            await checkSubscriptionStatus()
        }
    }
    
    private func checkSubscriptionStatus() async {
        isCheckingSubscription = true
        
        // Check subscription status
        await subscriptionManager.checkSubscriptionStatus()
        
        // Small delay for smooth transition
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isCheckingSubscription = false
        
        // If user has subscription, grant access
        if subscriptionManager.isSubscribed {
            onAccessGranted()
        }
    }
}

#Preview {
    SubscriptionGateView {
        print("Access granted!")
    }
}
