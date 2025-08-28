//
//  SignUpView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/11/25.
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel: SignUpViewModel
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State var isSignedUp: Bool = false
    
    init() {
        _viewModel = StateObject(wrappedValue: SignUpViewModel(appEnvironment: AppEnvironment()))
    }
    
    var body: some View {
        VStack {
            Label("Create An Account!", systemImage: "42.circle")
            
            TextField("Email", text: $email)
            TextField("Username", text: $username)
            SecureField("Password", text:  $password)
            
            Button("Sign Up") {
                Task {
                    await viewModel.signUp(email: email, username: username, password: password)
                }
            }
            
            // Navigate to home view after signing up
            .navigationDestination(isPresented: $isSignedUp) {
                HomeView()
                    .environmentObject(appEnvironment)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SignUpView()
        .environmentObject(AppEnvironment())
}
