//
//  ContentView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 7/31/25.
//

// ==========================================
// MARK: - ContentView.swift
// ==========================================
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    
    var body: some View {
        Group {
            if appEnvironment.appUser != nil {
                // User is logged in → go directly to HomeView
                HomeView()
            } else {
                // User NOT logged in → show welcome screen
                welcomeScreen
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
                            .font(.system(size: 100))
                            .foregroundColor(.orange)
                        
                        Text("RunTogether")
                            .font(.system(size: 48, weight: .bold))
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
                        
                        NavigationLink(destination: SignUpView()) {
                            Text("Sign Up")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 40)
                    
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
