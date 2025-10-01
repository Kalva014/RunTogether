//
//  LogInView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/20/25.
//

import SwiftUI

struct LogInView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel: LogInViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State var isLoggedIn: Bool = false

    init() {
        _viewModel = StateObject(wrappedValue: LogInViewModel())
    }

    var body: some View {
        VStack {
            Label("Welcome Back!", systemImage: "person.circle")
            
            TextField("Email", text: $email)
            SecureField("Password", text: $password)
            
            Button("Log In") {
                Task {
                    isLoggedIn = await viewModel.signIn(email: email, password: password, appEnvironment: appEnvironment)
                }
            }
            
            .navigationDestination(isPresented: $isLoggedIn) { HomeView()
                .environmentObject(appEnvironment)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

#Preview {
    let supabaseConnection = SupabaseConnection()
    return LogInView()
        .environmentObject(AppEnvironment(supabaseConnection: supabaseConnection))
}

