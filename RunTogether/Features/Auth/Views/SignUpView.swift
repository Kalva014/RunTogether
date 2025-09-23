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
    @State private var first_name: String = ""
    @State private var last_name: String = ""
    @State private var phone: String = ""
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
            TextField("first_name", text: $first_name)
            TextField("last_name", text: $last_name)
            SecureField("Password", text:  $password)
            
            Button("Sign Up") {
                Task {
                    isSignedUp = await viewModel.signUp(email: email, username: username, first_name: first_name, last_name: last_name, password: password)
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
