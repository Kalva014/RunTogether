//
//  SafetyDisclaimerView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 12/4/25.
//

import SwiftUI

struct SafetyDisclaimerView: View {
    @Binding var isPresented: Bool
    @State private var hasAgreed = false
    @State private var showError = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Warning icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                        .padding(.top, 60)
                    
                    // Title
                    Text("Important Safety Notice")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    // Main disclaimer
                    VStack(alignment: .leading, spacing: 16) {
                        DisclaimerSection(
                            icon: "heart.text.square",
                            title: "Consult Your Doctor",
                            text: "Running and physical exercise carry inherent risks. Consult with a qualified healthcare professional before starting any exercise program, especially if you have pre-existing health conditions."
                        )
                        
                        DisclaimerSection(
                            icon: "figure.run",
                            title: "Exercise at Your Own Risk",
                            text: "You assume all risks associated with using RunTogether. We are not responsible for any injuries, accidents, or health issues that may occur during your use of this app."
                        )
                        
                        DisclaimerSection(
                            icon: "stethoscope",
                            title: "Not Medical Advice",
                            text: "RunTogether does not provide medical advice, diagnosis, or treatment. The app's features, recommendations, and data are for informational purposes only and should not replace professional medical guidance."
                        )
                        
                        DisclaimerSection(
                            icon: "eye",
                            title: "Stay Aware",
                            text: "Always be aware of your surroundings. Do not use the app in ways that distract you from potential hazards, traffic, or unsafe conditions."
                        )
                        
                        DisclaimerSection(
                            icon: "person.2",
                            title: "Unsupervised Events",
                            text: "RunTogether does not supervise, verify, or guarantee the safety of any runs, routes, or events. Users participate at their own discretion and risk."
                        )
                        
                        DisclaimerSection(
                            icon: "flame",
                            title: "Warm Up & Cool Down",
                            text: "Always warm up before running and cool down afterward. Listen to your body and stop immediately if you experience pain, dizziness, or discomfort."
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Agreement checkbox
                    Button(action: {
                        hasAgreed.toggle()
                        showError = false
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: hasAgreed ? "checkmark.square.fill" : "square")
                                .font(.title2)
                                .foregroundColor(hasAgreed ? .orange : .gray)
                            
                            Text("I understand and agree to these terms. I acknowledge that running carries risks and I am using RunTogether at my own risk.")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    if showError {
                        Text("Please read and agree to continue")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    // Continue button
                    Button(action: {
                        if hasAgreed {
                            isPresented = false
                        } else {
                            showError = true
                        }
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(hasAgreed ? Color.orange : Color.gray)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                    .disabled(!hasAgreed)
                }
            }
        }
    }
}

struct DisclaimerSection: View {
    let icon: String
    let title: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    SafetyDisclaimerView(isPresented: .constant(true))
}
