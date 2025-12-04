//
//  PrivacyPolicyView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 12/4/25.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Privacy Policy")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 20)
                        
                        PrivacySection(
                            title: "1. Information We Collect",
                            content: """
                            We collect the following information when you use RunTogether:
                            
                            • Account Information: Email address, username, and profile details
                            • Running Data: Distance, pace, time, location data during runs
                            • Device Information: Device type, operating system, app version
                            • Usage Data: App interactions, features used, performance data
                            • Profile Customization: Selected sprites, preferences, settings
                            """
                        )
                        
                        PrivacySection(
                            title: "2. How We Use Your Information",
                            content: """
                            We use your information to:
                            
                            • Provide and improve the RunTogether service
                            • Track your running progress and statistics
                            • Enable multiplayer features and leaderboards
                            • Communicate with you about the app
                            • Ensure app security and prevent fraud
                            • Analyze app usage and performance
                            """
                        )
                        
                        PrivacySection(
                            title: "3. Location Data",
                            content: """
                            RunTogether uses location data to:
                            
                            • Track your running distance and route
                            • Calculate pace and speed
                            • Enable multiplayer race features
                            
                            Location data is collected only during active runs when you have granted permission. You can disable location access in your device settings at any time, though this will limit app functionality.
                            """
                        )
                        
                        PrivacySection(
                            title: "4. Data Sharing",
                            content: """
                            We do not sell your personal information. We may share data:
                            
                            • With other users: Your username, running statistics, and race results are visible to other users in multiplayer features
                            • Service Providers: We use third-party services (Supabase) to host and manage data
                            • Legal Requirements: We may disclose information if required by law
                            
                            Your email address and precise location data are never shared with other users.
                            """
                        )
                        
                        PrivacySection(
                            title: "5. Data Security",
                            content: """
                            We implement security measures to protect your data:
                            
                            • Encrypted data transmission
                            • Secure authentication
                            • Regular security updates
                            
                            However, no method of transmission over the internet is 100% secure. We cannot guarantee absolute security of your data.
                            """
                        )
                        
                        PrivacySection(
                            title: "6. Data Retention",
                            content: """
                            We retain your data:
                            
                            • Account data: Until you delete your account
                            • Running history: Indefinitely unless you request deletion
                            • Usage data: Up to 2 years for analytics purposes
                            
                            You can request deletion of your data by contacting us.
                            """
                        )
                        
                        PrivacySection(
                            title: "7. Your Rights",
                            content: """
                            You have the right to:
                            
                            • Access your personal data
                            • Correct inaccurate data
                            • Request deletion of your data
                            • Opt out of certain data collection
                            • Export your data
                            
                            To exercise these rights, contact us through the app or email.
                            """
                        )
                        
                        PrivacySection(
                            title: "8. Children's Privacy",
                            content: """
                            RunTogether is not intended for children under 13. We do not knowingly collect information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately.
                            """
                        )
                        
                        PrivacySection(
                            title: "9. Third-Party Services",
                            content: """
                            RunTogether uses third-party services:
                            
                            • Supabase: Database and authentication
                            • Apple HealthKit: Health data integration (if enabled)
                            
                            These services have their own privacy policies. We recommend reviewing them.
                            """
                        )
                        
                        PrivacySection(
                            title: "10. Changes to Privacy Policy",
                            content: """
                            We may update this Privacy Policy from time to time. We will notify you of significant changes through the app or by email. Continued use of the app after changes constitutes acceptance of the updated policy.
                            """
                        )
                        
                        PrivacySection(
                            title: "11. Contact Us",
                            content: """
                            If you have questions about this Privacy Policy or your data, please contact us through the app or at the email address provided in the app settings.
                            """
                        )
                        
                        Text("Last Updated: December 4, 2024")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
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
    }
}

struct PrivacySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.orange)
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    PrivacyPolicyView()
}
