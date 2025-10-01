//
//  ProfileTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/22/25.
//
import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel: ProfileTabViewModel
    @State var isSignedOut: Bool = false
    
    init() {
        _viewModel = StateObject(wrappedValue: ProfileTabViewModel())
    }

    var body: some View {
        VStack {
            Button("Edit Profile") {}
            Button("Sign Out") {
                Task {
                    await viewModel.signOut(appEnvironment: appEnvironment)
                }
            }
            Text("Profile")
            Text("First Name")
            Text("Last Name")
            Text("Location")
            Text("Top 3 finishes")
            Text("Last Race")
        }
        .navigationDestination(isPresented: $isSignedOut) { ContentView()
            .environmentObject(appEnvironment)
        }
    }
}

#Preview{
    let supabaseConnection = SupabaseConnection()
    return ProfileTabView()
        .environmentObject(AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"), supabaseConnection: supabaseConnection))
}
