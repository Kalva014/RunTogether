//
//  PaywallView.swift
//  RunTogether
//
//  Beautiful paywall with weekly, monthly, and yearly subscriptions
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPackage: Package?
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var isTrialEligible = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    
    var onSubscribe: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black, Color.orange.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    headerSection
                    
                    // Features list
                    featuresSection
                    
                    // Subscription packages
                    if let offering = subscriptionManager.currentOffering {
                        packagesSection(offering: offering)
                    } else {
                        ProgressView()
                            .tint(.orange)
                    }
                    
                    // Purchase button
                    purchaseButton
                    
                    // Legal links
                    legalSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
            
            // Close button removed - user must subscribe or use restore purchases
            
            // Loading overlay
            if subscriptionManager.isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.orange)
            }
        }
        .alert("Purchase Successful", isPresented: $showingSuccess) {
            Button("Continue") {
                onSubscribe?()
                dismiss()
            }
        } message: {
            Text("Welcome to RunTogether Premium!")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(subscriptionManager.errorMessage ?? "An error occurred")
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
        .task {
            await loadOfferings()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Run in a world that moves with you")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            if isTrialEligible {
                Text("Start your 7-day free trial")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text("Upgrade to unlock:")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            FeatureRow(
                icon: "🏃",
                title: "Real-Time Run Matching",
                description: "Instantly drop into group runs built around your pace, your vibe, and your goals — whether you're here for community or competition."
            )
            FeatureRow(
                icon: "🌍",
                title: "Live Avatar World",
                description: "Watch your avatar race across the route alongside others. Push harder in Race Mode with a clean, focused leaderboard."
            )
            FeatureRow(
                icon: "🏆",
                title: "Progress That Matters",
                description: "Level up, rise through global and friend-based rankings, and see your improvement in real time."
            )
            FeatureRow(
                icon: "💬",
                title: "Stay Connected, Stay Motivated",
                description: "Chat with your run group on the go. Make every session social, supportive, and fun."
            )
            FeatureRow(
                icon: "🔁",
                title: "Treadmill Mode, Reimagined",
                description: "Run indoors without losing the group. Use manual pace or your phone's sensors to keep your avatar perfectly in sync."
            )
            
            Text("Make every run interactive, competitive, and connected. Unlock the full experience.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Packages Section
    private func packagesSection(offering: Offering) -> some View {
        VStack(spacing: 12) {
            // Yearly (Best Value)
            if let yearlyPackage = offering.availablePackages.first(where: { $0.packageType == .annual }) {
                SubscriptionCard(
                    package: yearlyPackage,
                    isSelected: selectedPackage?.identifier == yearlyPackage.identifier,
                    badge: "BEST VALUE",
                    savings: "Save 60%",
                    isTrialEligible: isTrialEligible
                ) {
                    selectedPackage = yearlyPackage
                }
            }
            
            // Monthly (Most Popular)
            if let monthlyPackage = offering.availablePackages.first(where: { $0.packageType == .monthly }) {
                SubscriptionCard(
                    package: monthlyPackage,
                    isSelected: selectedPackage?.identifier == monthlyPackage.identifier,
                    badge: "MOST POPULAR",
                    savings: nil,
                    isTrialEligible: isTrialEligible
                ) {
                    selectedPackage = monthlyPackage
                }
            }
            
            // Weekly
            if let weeklyPackage = offering.availablePackages.first(where: { $0.packageType == .weekly }) {
                SubscriptionCard(
                    package: weeklyPackage,
                    isSelected: selectedPackage?.identifier == weeklyPackage.identifier,
                    badge: nil,
                    savings: nil,
                    isTrialEligible: isTrialEligible
                ) {
                    selectedPackage = weeklyPackage
                }
            }
        }
    }
    
    // MARK: - Purchase Button
    private var purchaseButton: some View {
        Button(action: handlePurchase) {
            HStack {
                if subscriptionManager.isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text(isTrialEligible ? "Start Free Trial" : "Subscribe Now")
                        .font(.headline)
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [.orange, .yellow],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .disabled(selectedPackage == nil || subscriptionManager.isLoading)
        .opacity(selectedPackage == nil ? 0.5 : 1.0)
        .padding(.top, 10)
    }
    
    // MARK: - Legal Section
    private var legalSection: some View {
        VStack(spacing: 12) {
            if isTrialEligible {
                Text("Free for 7 days, then \(selectedPackage?.localizedPriceString ?? ""). Cancel anytime.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            Button("Restore Purchases") {
                Task {
                    do {
                        try await subscriptionManager.restorePurchases()
                        if subscriptionManager.isSubscribed {
                            showingSuccess = true
                        } else {
                            showingError = true
                        }
                    } catch {
                        showingError = true
                    }
                }
            }
            .font(.subheadline)
            .foregroundColor(.orange)
            
            HStack(spacing: 20) {
                Button("Terms of Service") {
                    showingTermsOfService = true
                }
                Text("•")
                Button("Privacy Policy") {
                    showingPrivacyPolicy = true
                }
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(.top, 20)
    }
    
    // MARK: - Actions
    private func loadOfferings() async {
        do {
            try await subscriptionManager.fetchOfferings()
            
            // Auto-select yearly package (best value)
            if let offering = subscriptionManager.currentOffering {
                selectedPackage = offering.availablePackages.first(where: { $0.packageType == .annual })
                    ?? offering.availablePackages.first
                
                // Check trial eligibility
                if let package = selectedPackage {
                    isTrialEligible = try await subscriptionManager.checkTrialEligibility(package: package)
                }
            }
        } catch {
            showingError = true
        }
    }
    
    private func handlePurchase() {
        guard let package = selectedPackage else { return }
        
        Task {
            do {
                let success = try await subscriptionManager.purchase(package: package)
                if success {
                    showingSuccess = true
                }
            } catch {
                showingError = true
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Support both emoji and SF Symbols
            if icon.count == 1 || icon.contains("🏃") || icon.contains("🌍") || icon.contains("🏆") || icon.contains("💬") || icon.contains("🔁") {
                Text(icon)
                    .font(.title2)
                    .frame(width: 30)
            } else {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.orange)
                    .frame(width: 30)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Subscription Card
struct SubscriptionCard: View {
    let package: Package
    let isSelected: Bool
    let badge: String?
    let savings: String?
    let isTrialEligible: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Badge
                if let badge = badge {
                    Text(badge)
                        .font(.caption.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            badge == "BEST VALUE" ? Color.yellow : Color.orange
                        )
                        .cornerRadius(8, corners: [.topLeft, .topRight])
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(package.storeProduct.localizedTitle)
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            
                            if let savings = savings {
                                Text(savings)
                                    .font(.caption.bold())
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(6)
                            }
                        }
                        
                        if isTrialEligible {
                            Text("7 days free, then \(package.localizedPriceString)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            Text(package.localizedPriceString)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        if let period = package.storeProduct.subscriptionPeriod {
                            Text(formatPeriod(period))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .orange : .white.opacity(0.3))
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: badge == nil ? 16 : 0)
                        .fill(isSelected ? Color.orange.opacity(0.2) : Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: badge == nil ? 16 : 0)
                                .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                        )
                )
            }
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatPeriod(_ period: SubscriptionPeriod) -> String {
        let unit: String
        switch period.unit {
        case .day:
            unit = period.value == 1 ? "day" : "days"
        case .week:
            unit = period.value == 1 ? "week" : "weeks"
        case .month:
            unit = period.value == 1 ? "month" : "months"
        case .year:
            unit = period.value == 1 ? "year" : "years"
        @unknown default:
            unit = "period"
        }
        
        return "Billed every \(period.value) \(unit)"
    }
}

#Preview {
    PaywallView()
}
