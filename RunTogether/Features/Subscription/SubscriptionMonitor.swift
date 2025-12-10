//
//  SubscriptionMonitor.swift
//  RunTogether
//
//  Monitors subscription status and handles expiration
//

import SwiftUI
import Combine

/// Monitors subscription status throughout app lifecycle
@MainActor
class SubscriptionMonitor: ObservableObject {
    static let shared = SubscriptionMonitor()
    
    @Published var shouldShowPaywall = false
    @Published var subscriptionExpiredAlert = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupSubscriptionObserver()
    }
    
    /// Observe subscription manager changes
    private func setupSubscriptionObserver() {
        SubscriptionManager.shared.$isSubscribed
            .dropFirst() // Skip initial value
            .sink { [weak self] isSubscribed in
                if !isSubscribed {
                    // Subscription became inactive
                    self?.handleSubscriptionLost()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Check current subscription status
    func checkSubscriptionStatus() async {
        await SubscriptionManager.shared.checkSubscriptionStatus()
        
        if !SubscriptionManager.shared.isSubscribed {
            handleSubscriptionLost()
        }
    }
    
    /// Handle subscription loss/expiration
    private func handleSubscriptionLost() {
        print("⚠️ Subscription lost or expired")
        subscriptionExpiredAlert = true
        shouldShowPaywall = true
    }
    
    /// Reset monitor state (call when user subscribes)
    func resetState() {
        shouldShowPaywall = false
        subscriptionExpiredAlert = false
    }
    
}

/// View modifier to monitor subscription and show paywall when expired
struct SubscriptionMonitorModifier: ViewModifier {
    @StateObject private var monitor = SubscriptionMonitor.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var hasCheckedInitialStatus = false
    @Environment(\.scenePhase) private var scenePhase
    
    func body(content: Content) -> some View {
        content
            .task {
                // Only check on first appearance, not every time
                if !hasCheckedInitialStatus {
                    await monitor.checkSubscriptionStatus()
                    hasCheckedInitialStatus = true
                    
                    // Show paywall immediately if no subscription
                    if !subscriptionManager.isSubscribed {
                        showPaywall = true
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Only check when app becomes active from background
                if newPhase == .active && oldPhase == .background {
                    Task {
                        await monitor.checkSubscriptionStatus()
                    }
                }
            }
            .onChange(of: monitor.shouldShowPaywall) { _, shouldShow in
                // Only show if subscription is actually inactive
                if shouldShow && !subscriptionManager.isSubscribed {
                    showPaywall = true
                }
            }
            .onChange(of: subscriptionManager.isSubscribed) { _, isSubscribed in
                // Dismiss paywall when subscription becomes active
                if isSubscribed {
                    showPaywall = false
                    monitor.resetState()
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView(onSubscribe: {
                    monitor.resetState()
                })
                .interactiveDismissDisabled() // Prevent dismissal without subscribing
            }
            .alert("Subscription Expired", isPresented: $monitor.subscriptionExpiredAlert) {
                Button("Renew Now") {
                    showPaywall = true
                }
            } message: {
                Text("Your premium subscription has expired. Please renew to continue using RunTogether.")
            }
    }
}

extension View {
    /// Add subscription monitoring to any view
    func monitorSubscription() -> some View {
        self.modifier(SubscriptionMonitorModifier())
    }
}
