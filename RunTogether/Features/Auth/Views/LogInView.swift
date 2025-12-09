//
//  LogInView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/20/25.
//
// ==========================================
// MARK: - LogInView.swift
// ==========================================
import SwiftUI

struct LogInView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel: LogInViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State var isLoggedIn: Bool = false
    @State private var showForgotPasswordAlert: Bool = false
    @State private var resetEmail: String = ""
    @State private var showResetSuccessAlert: Bool = false
    @State private var showResetErrorAlert: Bool = false

    init() {
        _viewModel = StateObject(wrappedValue: LogInViewModel())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                    
                    Text("RunTogether")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 60)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        SecureField("Enter your password", text: $password)
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
                    appEnvironment.soundManager.playTap()
                    Task {
                        let success = await viewModel.signIn(
                            email: email,
                            password: password,
                            appEnvironment: appEnvironment
                        )
                        if success {
                            appEnvironment.soundManager.playSuccess()
                        } else {
                            appEnvironment.soundManager.playError()
                        }
                        isLoggedIn = success
                    }
                }) {
                    Text("Log In")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .disabled(email.isEmpty || password.isEmpty)
                .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1.0)
                
                Button(action: {
                    appEnvironment.soundManager.playTap()
                    resetEmail = email
                    showForgotPasswordAlert = true
                }) {
                    Text("Forgot Password?")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                .padding(.top, 12)
                
                Spacer()
                Spacer()
            }
            
            .navigationDestination(isPresented: $isLoggedIn) {
                HomeView()
                    .environmentObject(appEnvironment)
            }
            .alert("Reset Password", isPresented: $showForgotPasswordAlert) {
                TextField("Email", text: $resetEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                Button("Cancel", role: .cancel) {
                    appEnvironment.soundManager.playTap()
                }
                Button("Send Reset Link") {
                    Task {
                        appEnvironment.soundManager.playTap()
                        let success = await viewModel.resetPassword(
                            email: resetEmail,
                            appEnvironment: appEnvironment
                        )
                        if success {
                            appEnvironment.soundManager.playSuccess()
                            showResetSuccessAlert = true
                        } else {
                            appEnvironment.soundManager.playError()
                            showResetErrorAlert = true
                        }
                    }
                }
            } message: {
                Text("Enter your email address to receive a password reset link.")
            }
            .alert("Success", isPresented: $showResetSuccessAlert) {
                Button("OK") {
                    appEnvironment.soundManager.playTap()
                }
            } message: {
                Text("Password reset link has been sent to \(resetEmail). Please check your email.")
            }
            .alert("Error", isPresented: $showResetErrorAlert) {
                Button("OK") {
                    appEnvironment.soundManager.playTap()
                }
            } message: {
                Text(viewModel.errorMessage ?? "Failed to send password reset email. Please try again.")
            }
        }
    }
}


#Preview {
    let supabaseConnection = SupabaseConnection()
    return LogInView()
        .environmentObject(AppEnvironment(supabaseConnection: supabaseConnection))
}

