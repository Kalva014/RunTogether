//
//  ContentView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 7/31/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var showOnboarding = false
    @State private var onboardingCompleted = false
    @State private var hasCheckedOnboarding = false
    @State private var showResetPassword = false
    
    var body: some View {
        Group {
            if let user = appEnvironment.appUser {
                // User is logged in
                if OnboardingManager.shared.hasSeenOnboarding(for: user.id) || onboardingCompleted {
                    // Onboarding complete → show HomeView
                    HomeView()
                } else {
                    // First time user → show onboarding first
                    Color.black.ignoresSafeArea()
                        .onAppear {
                            guard !hasCheckedOnboarding else { return }
                            hasCheckedOnboarding = true
                            // Small delay for smoother transition
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showOnboarding = true
                            }
                        }
                }
            } else {
                // User NOT logged in → show welcome screen
                welcomeScreen
            }
        }
        .id(appEnvironment.appUser?.id ?? "logged-out")
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
            onboardingCompleted = true
            hasCheckedOnboarding = false
        }) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .sheet(isPresented: $showResetPassword) {
            ResetPasswordView()
                .environmentObject(appEnvironment)
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("📱 Deep link received: \(url.absoluteString)")
        
        // Handle password reset deep link
        if url.scheme == "runtogether" && url.host == "reset-password" {
            Task {
                do {
                    // Use Supabase's session method to handle the deep link
                    // This exchanges the code for a session
                    try await appEnvironment.supabaseConnection.client.auth.session(from: url)
                    
                    print("✅ Session established from deep link")
                    
                    // Show the reset password view
                    await MainActor.run {
                        showResetPassword = true
                    }
                } catch {
                    print("❌ Error handling deep link: \(error)")
                }
            }
        }
    }
}

extension ContentView {
    private var welcomeScreen: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Logo and branding
                    VStack(spacing: 20) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: ResponsiveLayout.titleFontSize * 2))
                            .foregroundColor(.orange)
                        
                        Text("RunTogether")
                            .font(.system(size: ResponsiveLayout.titleFontSize, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Your social running companion")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 60)
                    
                    // Authentication buttons
                    VStack(spacing: 16) {
                        NavigationLink(destination: LogInView()) {
                            Text("Log In")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            appEnvironment.soundManager.playNavigation()
                        })
                        
                        NavigationLink(destination: SignUpView()) {
                            Text("Sign Up")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            appEnvironment.soundManager.playNavigation()
                        })
                    }
                    .padding(.horizontal, ResponsiveLayout.horizontalPadding * 2)
                    
                    Spacer()
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    let supabaseConnection = SupabaseConnection()
    return ContentView()
        .environmentObject(AppEnvironment(supabaseConnection: supabaseConnection))
}
