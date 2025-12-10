//
//  ManageSubscriptionView.swift
//  RunTogether
//
//  View for users to manage their subscription
//

import SwiftUI
import RevenueCat

struct ManageSubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingPaywall = false
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Current Subscription Status
                    if subscriptionManager.isSubscribed {
                        currentSubscriptionSection
                    } else {
                        noSubscriptionSection
                    }
                    
                    // Manage Options
                    manageOptionsSection
                    
                    // Help Section
                    helpSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
        }
        .navigationTitle("Manage Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaywall) {
            PaywallView {
                Task {
                    await subscriptionManager.checkSubscriptionStatus()
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: subscriptionManager.isSubscribed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(subscriptionManager.isSubscribed ? .green : .orange)
            
            Text(subscriptionManager.isSubscribed ? "Active Subscription" : "No Active Subscription")
                .font(.title2.bold())
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Current Subscription Section
    private var currentSubscriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Plan")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Tier:")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(subscriptionManager.subscriptionTier.displayName)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
                
                if let expirationDate = subscriptionManager.customerInfo?.entitlements[subscriptionManager.premiumEntitlementID]?.expirationDate {
                    HStack {
                        Text("Renews:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(expirationDate, style: .date)
                            .foregroundColor(.white)
                    }
                }
                
                HStack {
                    Text("Status:")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Active")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - No Subscription Section
    private var noSubscriptionSection: some View {
        VStack(spacing: 16) {
            Text("You don't have an active subscription")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button(action: {
                showingPaywall = true
            }) {
                Text("View Plans")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Manage Options Section
    private var manageOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manage")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                if subscriptionManager.isSubscribed {
                    // Change Plan
                    Button(action: {
                        showingPaywall = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.orange)
                            Text("Change Plan")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Manage in App Store
                    Button(action: {
                        Task {
                            await openManageSubscriptions()
                        }
                    }) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.orange)
                            Text("Manage in App Store")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                // Restore Purchases
                Button(action: {
                    Task {
                        await restorePurchases()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                        Text("Restore Purchases")
                            .foregroundColor(.white)
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .tint(.orange)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
        }
    }
    
    // MARK: - Help Section
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Need Help?")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("To cancel your subscription:")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    helpStep(number: "1", text: "Open the Settings app on your iPhone")
                    helpStep(number: "2", text: "Tap your name at the top")
                    helpStep(number: "3", text: "Tap Subscriptions")
                    helpStep(number: "4", text: "Select RunTogether")
                    helpStep(number: "5", text: "Tap Cancel Subscription")
                }
                
                Text("Or tap 'Manage in App Store' above to go directly to your subscriptions.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func helpStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .background(Color.orange)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Actions
    private func openManageSubscriptions() async {
        do {
            let url = try await subscriptionManager.getManageSubscriptionURL()
            if await UIApplication.shared.canOpenURL(url) {
                await UIApplication.shared.open(url)
            }
        } catch {
            print("Error opening manage subscriptions: \(error)")
        }
    }
    
    private func restorePurchases() async {
        isLoading = true
        do {
            try await subscriptionManager.restorePurchases()
            // Success feedback
        } catch {
            print("Error restoring purchases: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ManageSubscriptionView()
    }
}
