//
//  SubscriptionManager.swift
//  RunTogether
//
//  Production-ready subscription management with RevenueCat
//

import Foundation
import RevenueCat
import Supabase

/// Manages in-app subscriptions with RevenueCat and syncs with Supabase
@MainActor
class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    @Published var isSubscribed: Bool = false
    @Published var currentOffering: Offering?
    @Published var customerInfo: CustomerInfo?
    @Published var subscriptionTier: SubscriptionTier = .free
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Entitlement Identifiers
    // These must match your RevenueCat dashboard configuration
    let premiumEntitlementID = "premium" // Made public for ManageSubscriptionView
    
    // MARK: - Initialization
    private override init() {}
    
    /// Configure RevenueCat on app launch
    /// Call this in AppDelegate.didFinishLaunchingWithOptions
    func configure(apiKey: String) {
        Purchases.logLevel = .debug // Set to .info for production
        
        // Configure with StoreKit 2 for proper testing
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: apiKey)
                .with(storeKitVersion: .storeKit2)
                .build()
        )
        
        // Listen for customer info updates
        Purchases.shared.delegate = self
        
        print("✅ RevenueCat configured with StoreKit 2")
    }
    
    // MARK: - User Authentication Integration
    /// Link RevenueCat user to Supabase user ID
    /// Call this after successful Supabase authentication
    func identifyUser(supabaseUserId: UUID) async throws {
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(supabaseUserId.uuidString)
            await updateSubscriptionStatus(customerInfo: customerInfo)
            print("✅ RevenueCat user identified: \(supabaseUserId)")
        } catch {
            print("❌ Error identifying user: \(error.localizedDescription)")
            throw SubscriptionError.identificationFailed
        }
    }
    
    /// Log out current user from RevenueCat
    func logoutUser() async throws {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            await updateSubscriptionStatus(customerInfo: customerInfo)
            print("✅ RevenueCat user logged out")
        } catch {
            print("❌ Error logging out: \(error.localizedDescription)")
            throw SubscriptionError.logoutFailed
        }
    }
    
    // MARK: - Subscription Status
    /// Fetch current subscription status
    func checkSubscriptionStatus() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            await updateSubscriptionStatus(customerInfo: customerInfo)
        } catch {
            print("❌ Error fetching subscription status: \(error.localizedDescription)")
            errorMessage = "Failed to check subscription status"
        }
        
        isLoading = false
    }
    
    /// Update local subscription state from CustomerInfo
    private func updateSubscriptionStatus(customerInfo: CustomerInfo) async {
        self.customerInfo = customerInfo
        
        // Check if user has active premium entitlement
        if let entitlement = customerInfo.entitlements[premiumEntitlementID],
           entitlement.isActive {
            self.isSubscribed = true
            
            // Determine subscription tier based on product identifier
            let productId = entitlement.productIdentifier
            self.subscriptionTier = SubscriptionTier.from(productId: productId)
            
            print("✅ Active subscription: \(subscriptionTier.rawValue)")
        } else {
            self.isSubscribed = false
            self.subscriptionTier = .free
            print("ℹ️ No active subscription")
        }
    }
    
    // MARK: - Offerings & Packages
    /// Fetch available subscription offerings from RevenueCat
    func fetchOfferings() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let offerings = try await Purchases.shared.offerings()
            
            guard let currentOffering = offerings.current else {
                throw SubscriptionError.noOfferingsAvailable
            }
            
            self.currentOffering = currentOffering
            print("✅ Offerings fetched: \(currentOffering.availablePackages.count) packages")
        } catch {
            print("❌ Error fetching offerings: \(error.localizedDescription)")
            errorMessage = "Failed to load subscription options"
            throw SubscriptionError.offeringsFetchFailed
        }
        
        isLoading = false
    }
    
    /// Get specific package by type
    func getPackage(type: PackageType) -> Package? {
        return currentOffering?.availablePackages.first { $0.packageType == type }
    }
    
    // MARK: - Purchase Flow
    /// Purchase a subscription package
    func purchase(package: Package) async throws -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            
            if userCancelled {
                print("ℹ️ User cancelled purchase")
                isLoading = false
                return false
            }
            
            await updateSubscriptionStatus(customerInfo: customerInfo)
            
            // Sync subscription status to Supabase
            await syncSubscriptionToSupabase()
            
            print("✅ Purchase successful")
            isLoading = false
            return true
            
        } catch let error as RevenueCat.ErrorCode {
            print("❌ Purchase error: \(error.localizedDescription)")
            
            // Handle specific error cases
            switch error {
            case .purchaseCancelledError:
                errorMessage = "Purchase was cancelled"
            case .productAlreadyPurchasedError:
                errorMessage = "You already own this subscription"
            case .paymentPendingError:
                errorMessage = "Payment is pending approval"
            case .networkError:
                errorMessage = "Network error. Please check your connection"
            default:
                errorMessage = "Purchase failed. Please try again"
            }
            
            isLoading = false
            throw SubscriptionError.purchaseFailed(error.localizedDescription)
        } catch {
            print("❌ Purchase error: \(error.localizedDescription)")
            errorMessage = "Purchase failed. Please try again"
            isLoading = false
            throw SubscriptionError.purchaseFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Restore Purchases
    /// Restore previous purchases (required by Apple)
    func restorePurchases() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            await updateSubscriptionStatus(customerInfo: customerInfo)
            
            if isSubscribed {
                print("✅ Purchases restored successfully")
            } else {
                print("ℹ️ No purchases to restore")
                errorMessage = "No previous purchases found"
            }
            
        } catch {
            print("❌ Error restoring purchases: \(error.localizedDescription)")
            errorMessage = "Failed to restore purchases"
            throw SubscriptionError.restoreFailed
        }
        
        isLoading = false
    }
    
    // MARK: - Promotional Offers
    /// Check if user is eligible for introductory pricing (7-day trial)
    func checkTrialEligibility(package: Package) async throws -> Bool {
        do {
            let eligibility = try await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: [package.storeProduct.productIdentifier])
            
            if let status = eligibility[package.storeProduct.productIdentifier] {
                return status.status == .eligible
            }
            
            return false
        } catch {
            print("❌ Error checking trial eligibility: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Supabase Sync
    /// Sync subscription status to Supabase database
    private func syncSubscriptionToSupabase() async {
        guard let customerInfo = customerInfo else { return }
        
        // You can store subscription data in your Supabase database
        // This is useful for backend validation and analytics
        
        let subscriptionData: [String: Any] = [
            "is_subscribed": isSubscribed,
            "subscription_tier": subscriptionTier.rawValue,
            "expires_at": customerInfo.entitlements[premiumEntitlementID]?.expirationDate?.ISO8601Format() ?? "",
            "updated_at": Date().ISO8601Format()
        ]
        
        print("ℹ️ Subscription data ready for Supabase sync: \(subscriptionData)")
        
        // TODO: Implement actual Supabase update
        // This would require adding a subscriptions table or updating the Profiles table
        // Example:
        // try await supabaseConnection.client
        //     .from("Profiles")
        //     .update(subscriptionData)
        //     .eq("id", value: userId)
        //     .execute()
    }
    
    // MARK: - Subscription Management URLs
    /// Get URL to manage subscription in App Store
    func getManageSubscriptionURL() async throws -> URL {
        if #available(iOS 15.0, *) {
            try await Purchases.shared.showManageSubscriptions()
            // Return fallback URL since showManageSubscriptions returns Void
            return URL(string: "https://apps.apple.com/account/subscriptions")!
        } else {
            // Fallback for iOS 14
            return URL(string: "https://apps.apple.com/account/subscriptions")!
        }
    }
    
    // MARK: - Feature Access Control
    /// Check if user has access to premium features
    func hasPremiumAccess() -> Bool {
        return isSubscribed
    }
    
    /// Check if user has access to specific feature tier
    func hasAccess(to tier: SubscriptionTier) -> Bool {
        return subscriptionTier.level >= tier.level
    }
}

// MARK: - PurchasesDelegate
extension SubscriptionManager: PurchasesDelegate {
    /// Called when customer info is updated
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            await updateSubscriptionStatus(customerInfo: customerInfo)
            print("ℹ️ Customer info updated via delegate")
        }
    }
}

// MARK: - Supporting Types
enum SubscriptionTier: String, Codable {
    case free = "free"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    var level: Int {
        switch self {
        case .free: return 0
        case .weekly: return 1
        case .monthly: return 2
        case .yearly: return 3
        }
    }
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
    
    static func from(productId: String) -> SubscriptionTier {
        if productId.contains("weekly") {
            return .weekly
        } else if productId.contains("monthly") {
            return .monthly
        } else if productId.contains("yearly") || productId.contains("annual") {
            return .yearly
        }
        return .free
    }
}

enum SubscriptionError: LocalizedError {
    case identificationFailed
    case logoutFailed
    case noOfferingsAvailable
    case offeringsFetchFailed
    case purchaseFailed(String)
    case restoreFailed
    
    var errorDescription: String? {
        switch self {
        case .identificationFailed:
            return "Failed to identify user"
        case .logoutFailed:
            return "Failed to log out"
        case .noOfferingsAvailable:
            return "No subscription options available"
        case .offeringsFetchFailed:
            return "Failed to fetch subscription options"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .restoreFailed:
            return "Failed to restore purchases"
        }
    }
}
