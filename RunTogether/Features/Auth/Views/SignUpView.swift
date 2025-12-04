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
    @State private var country: String = ""
    @State private var password: String = ""
    
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
                        
                        countryPicker
                        
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
                        appEnvironment.soundManager.playTap()
                        Task {
                            let success = await viewModel.signUp(
                                email: email,
                                username: username,
                                first_name: first_name,
                                last_name: last_name,
                                country: country.isEmpty ? nil : country,
                                password: password,
                                appEnvironment: appEnvironment
                            )
                            if success {
                                appEnvironment.soundManager.playSuccess()
                                // ContentView will automatically handle onboarding and navigation
                            } else {
                                appEnvironment.soundManager.playError()
                            }
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
    
    private var countryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Country")
                .font(.caption)
                .foregroundColor(.gray)
            
            Menu {
                ForEach(CountryFlagHelper.countries, id: \.self) { countryName in
                    Button(action: {
                        country = countryName
                    }) {
                        HStack {
                            Text(CountryFlagHelper.flagEmoji(for: countryName))
                            Text(countryName)
                        }
                    }
                }
            } label: {
                HStack {
                    if country.isEmpty {
                        Text("Select your country")
                            .foregroundColor(.gray)
                    } else {
                        HStack(spacing: 6) {
                            Text(CountryFlagHelper.flagEmoji(for: country))
                                .font(.system(size: 20))
                            Text(country)
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
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
