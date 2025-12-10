//
//  SubscriptionSettingsView.swift
//  RunTogether
//
//  Manage subscription and view status
//

import SwiftUI
import RevenueCat

struct SubscriptionSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    @State private var showingManageSubscription = false
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Subscription status card
                        statusCard
                        
                        // Features list
                        if subscriptionManager.isSubscribed {
                            activeSubscriptionSection
                        } else {
                            freeUserSection
                        }
                        
                        // Action buttons
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView {
                // Refresh status after subscription
                Task {
                    await subscriptionManager.checkSubscriptionStatus()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(subscriptionManager.errorMessage ?? "An error occurred")
        }
        .task {
            await subscriptionManager.checkSubscriptionStatus()
        }
    }
    
    // MARK: - Status Card
    private var statusCard: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: subscriptionManager.isSubscribed ? "crown.fill" : "crown")
                .font(.system(size: 50))
                .foregroundStyle(
                    subscriptionManager.isSubscribed ?
                    LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [.gray], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            // Status text
            Text(subscriptionManager.isSubscribed ? "Premium Active" : "Free Plan")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            if subscriptionManager.isSubscribed {
                Text(subscriptionManager.subscriptionTier.displayName)
                    .font(.subheadline)
                    .foregroundColor(.orange)
                
                // Expiration date
                if let expirationDate = subscriptionManager.customerInfo?.entitlements["premium"]?.expirationDate {
                    if let willRenew = subscriptionManager.customerInfo?.entitlements["premium"]?.willRenew {
                        Text(willRenew ? "Renews \(expirationDate.formatted(date: .abbreviated, time: .omitted))" : "Expires \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            } else {
                Text("Upgrade to unlock all features")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // MARK: - Active Subscription Section
    private var activeSubscriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium Features")
                .font(.headline)
                .foregroundColor(.white)
            
            FeatureStatusRow(icon: "infinity", title: "Unlimited Runs", isActive: true)
            FeatureStatusRow(icon: "person.3.fill", title: "Multiplayer Races", isActive: true)
            FeatureStatusRow(icon: "chart.line.uptrend.xyaxis", title: "Advanced Analytics", isActive: true)
            FeatureStatusRow(icon: "trophy.fill", title: "Global Leaderboards", isActive: true)
            FeatureStatusRow(icon: "figure.run", title: "Custom Avatars", isActive: true)
            FeatureStatusRow(icon: "bell.badge.fill", title: "Priority Support", isActive: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - Free User Section
    private var freeUserSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Features")
                .font(.headline)
                .foregroundColor(.white)
            
            FeatureStatusRow(icon: "figure.run", title: "Basic Running", isActive: true)
            FeatureStatusRow(icon: "clock", title: "Limited Runs (5/day)", isActive: true)
            FeatureStatusRow(icon: "infinity", title: "Unlimited Runs", isActive: false)
            FeatureStatusRow(icon: "person.3.fill", title: "Multiplayer Races", isActive: false)
            FeatureStatusRow(icon: "chart.line.uptrend.xyaxis", title: "Advanced Analytics", isActive: false)
            FeatureStatusRow(icon: "trophy.fill", title: "Global Leaderboards", isActive: false)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if subscriptionManager.isSubscribed {
                // Manage subscription button
                Button(action: {
                    Task {
                        do {
                            let url = try await subscriptionManager.getManageSubscriptionURL()
                            await UIApplication.shared.open(url)
                        } catch {
                            showingError = true
                        }
                    }
                }) {
                    Text("Manage Subscription")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
            } else {
                // Upgrade button
                Button(action: {
                    showingPaywall = true
                }) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Upgrade to Premium")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
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
            
            // Restore purchases button
            Button(action: {
                Task {
                    do {
                        try await subscriptionManager.restorePurchases()
                        if !subscriptionManager.isSubscribed {
                            showingError = true
                        }
                    } catch {
                        showingError = true
                    }
                }
            }) {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - Feature Status Row
struct FeatureStatusRow: View {
    let icon: String
    let title: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isActive ? .orange : .gray)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(isActive ? .white : .white.opacity(0.5))
            
            Spacer()
            
            Image(systemName: isActive ? "checkmark.circle.fill" : "lock.fill")
                .foregroundColor(isActive ? .green : .gray)
        }
    }
}

#Preview {
    SubscriptionSettingsView()
}
