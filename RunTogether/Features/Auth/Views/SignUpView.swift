//
//  SignUpView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/11/25.
//

// ==========================================
// MARK: - SignUpView.swift
// ==========================================
import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel: SignUpViewModel
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var first_name: String = ""
    @State private var last_name: String = ""
    @State private var password: String = ""
    @State var isSignedUp: Bool = false
    
    init() {
        _viewModel = StateObject(wrappedValue: SignUpViewModel())
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    
                    VStack(spacing: 16) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.orange)
                        
                        Text("Create Account")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Join the running community")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 40)
                    
                    VStack(spacing: 16) {
                        inputField(title: "Email", text: $email, placeholder: "Enter your email")
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        inputField(title: "Username", text: $username, placeholder: "Choose a username")
                            .autocapitalization(.none)
                        
                        inputField(title: "First Name", text: $first_name, placeholder: "Enter your first name")
                        
                        inputField(title: "Last Name", text: $last_name, placeholder: "Enter your last name")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            SecureField("Create a password", text: $password)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                    
                    Button(action: {
                        Task {
                            isSignedUp = await viewModel.signUp(
                                email: email,
                                username: username,
                                first_name: first_name,
                                last_name: last_name,
                                password: password,
                                appEnvironment: appEnvironment
                            )
                        }
                    }) {
                        Text("Sign Up")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.5)
                    
                    Spacer(minLength: 40)
                }
            }
            
            .navigationDestination(isPresented: $isSignedUp) {
                HomeView()
                    .environmentObject(appEnvironment)
            }
        }
    }
    
    private func inputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            TextField(placeholder, text: text)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.white)
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !username.isEmpty &&
        !first_name.isEmpty &&
        !last_name.isEmpty &&
        !password.isEmpty
    }
}
#Preview {
    let supabaseConnection = SupabaseConnection()
    return SignUpView()
        .environmentObject(AppEnvironment(supabaseConnection: supabaseConnection))
}
