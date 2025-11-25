//
//  OnboardingView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 11/25/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "figure.run.circle.fill",
            title: "Welcome to RunTogether",
            description: "Your social running companion. Race with friends, compete globally, and track your progress.",
            color: .orange
        ),
        OnboardingPage(
            icon: "trophy.fill",
            title: "Competitive Racing",
            description: "Join ranked races to climb the leaderboard, or run casually at your own pace. Every race counts!",
            color: .orange
        ),
        OnboardingPage(
            icon: "person.2.fill",
            title: "Run with Friends",
            description: "Create or join run clubs, add friends, and see who's running in real-time.",
            color: .blue
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Your Progress",
            description: "Monitor your stats, improve your pace, and watch your rank grow as you complete more races.",
            color: .green
        ),
        OnboardingPage(
            icon: "figure.walk",
            title: "Treadmill Support",
            description: "Enable treadmill mode to run with others indoors.",
            color: .purple
        ),
        OnboardingPage(
            icon: "calendar.badge.plus",
            title: "Train and Run Together",
            description: "Share race IDs so friends can join your training runs, compare progress, and stay motivated throughout your running journey.",
            color: .teal
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    
                    Button(action: completeOnboarding) {
                        Text("Skip")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                Spacer()
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.orange : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 20)
                
                // Action button
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation(.spring(response: 0.3)) {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func completeOnboarding() {
        OnboardingManager.shared.markOnboardingComplete()
        withAnimation {
            isPresented = false
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Individual Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Image(systemName: page.icon)
                .font(.system(size: 100))
                .foregroundColor(page.color)
                .shadow(color: page.color.opacity(0.3), radius: 20)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
