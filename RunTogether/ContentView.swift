//
//  ContentView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 7/31/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment

    var body: some View {
        NavigationStack {
            // Show different views based on authentication status
            if appEnvironment.appUser != nil {
                HomeView()
            } else {
                VStack {
                    NavigationLink {
                        SignUpView()
                            .environmentObject(appEnvironment)
                    } label: {
                        Text("Sign Up!")
                    }
                    
                    NavigationLink {
                        LogInView()
                            .environmentObject(appEnvironment)
                    } label: {
                        Text("Log In!")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

#Preview {
    let supabaseConnection = SupabaseConnection()
    return ContentView()
        .environmentObject(AppEnvironment(supabaseConnection: supabaseConnection))
}
