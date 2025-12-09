//
//  ResetPasswordView.swift
//  RunTogether
//
//  Created for password reset functionality
//

import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @Environment(\.dismiss) var dismiss
    
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var showSuccessAlert: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                    
                    Text("Reset Password")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Enter your new password")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 60)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Password")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        SecureField("Enter new password", text: $newPassword)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        SecureField("Confirm new password", text: $confirmPassword)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    if let errorMessage = errorMessage {
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
                        await resetPassword()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Reset Password")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .background(Color.orange)
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .disabled(newPassword.isEmpty || confirmPassword.isEmpty || isLoading)
                .opacity(newPassword.isEmpty || confirmPassword.isEmpty || isLoading ? 0.5 : 1.0)
                
                Spacer()
                Spacer()
            }
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                appEnvironment.soundManager.playTap()
                dismiss()
            }
        } message: {
            Text("Your password has been reset successfully. You can now log in with your new password.")
        }
    }
    
    private func resetPassword() async {
        // Validate passwords match
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match"
            appEnvironment.soundManager.playError()
            return
        }
        
        // Validate password length
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            appEnvironment.soundManager.playError()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Update the password using the access token
            try await appEnvironment.supabaseConnection.client.auth.update(
                user: .init(password: newPassword)
            )
            
            appEnvironment.soundManager.playSuccess()
            showSuccessAlert = true
        } catch {
            errorMessage = error.localizedDescription
            appEnvironment.soundManager.playError()
            print("Error resetting password: \(error)")
        }
        
        isLoading = false
    }
}

#Preview {
    let supabaseConnection = SupabaseConnection()
    return ResetPasswordView()
        .environmentObject(AppEnvironment(supabaseConnection: supabaseConnection))
}
