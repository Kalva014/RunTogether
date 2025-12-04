//
//  TermsOfServiceView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 12/4/25.
//

import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Terms of Service")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 20)
                        
                        // Safety and Health Disclaimers
                        TermsSection(
                            title: "1. Health and Safety Disclaimer",
                            content: """
                            RunTogether is a fitness tracking and social running application. By using this app, you acknowledge and agree to the following:
                            
                            • Running and physical exercise carry inherent risks, including but not limited to injury, illness, or death.
                            • You should consult with a qualified healthcare professional before starting any exercise program.
                            • You use RunTogether entirely at your own risk.
                            • RunTogether does not provide medical advice, diagnosis, or treatment.
                            • The app's features, recommendations, and data are for informational purposes only.
                            • You are solely responsible for your physical condition and ability to participate in running activities.
                            """
                        )
                        
                        TermsSection(
                            title: "2. No Supervision or Verification",
                            content: """
                            RunTogether does not:
                            
                            • Supervise, monitor, or verify the safety of any runs, routes, or events
                            • Guarantee the accuracy of any route information or distance measurements
                            • Certify routes as "safe" or suitable for running
                            • Provide real-time safety monitoring or emergency services
                            • Verify the identity, qualifications, or intentions of other users
                            
                            All runs, events, and interactions with other users are at your own discretion and risk.
                            """
                        )
                        
                        TermsSection(
                            title: "3. User Responsibilities",
                            content: """
                            You agree to:
                            
                            • Stay aware of your surroundings at all times while running
                            • Not use the app in ways that distract you from potential hazards
                            • Follow all traffic laws and regulations
                            • Use treadmills and other equipment according to manufacturer instructions
                            • Not rely solely on the app for navigation or safety
                            • Take appropriate safety precautions based on weather, terrain, and time of day
                            • Carry identification and emergency contact information
                            • Inform others of your running plans when appropriate
                            """
                        )
                        
                        TermsSection(
                            title: "4. Limitation of Liability",
                            content: """
                            To the maximum extent permitted by law:
                            
                            • RunTogether and its developers are not liable for any injuries, accidents, or health issues arising from your use of the app
                            • We make no warranties about the accuracy, reliability, or completeness of any information provided
                            • We are not responsible for the actions or conduct of other users
                            • You waive any claims against RunTogether related to your participation in running activities
                            """
                        )
                        
                        TermsSection(
                            title: "5. No Medical or Professional Advice",
                            content: """
                            RunTogether does not provide:
                            
                            • Medical advice, diagnosis, or treatment
                            • Professional fitness training or coaching
                            • Nutritional or dietary guidance
                            • Emergency services or medical assistance
                            
                            Any information provided by the app should not replace consultation with qualified professionals.
                            """
                        )
                        
                        TermsSection(
                            title: "6. User Conduct",
                            content: """
                            You agree not to:
                            
                            • Use the app while operating a vehicle
                            • Interact with the app while crossing streets or in hazardous situations
                            • Misrepresent your location, performance, or identity
                            • Harass, threaten, or harm other users
                            • Use the app for any illegal purposes
                            """
                        )
                        
                        TermsSection(
                            title: "7. Changes to Terms",
                            content: """
                            We reserve the right to modify these Terms of Service at any time. Continued use of the app after changes constitutes acceptance of the new terms.
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

struct TermsSection: View {
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
    TermsOfServiceView()
}
