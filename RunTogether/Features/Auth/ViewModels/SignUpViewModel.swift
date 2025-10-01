//
//  SignUpViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/11/25.
//

import Foundation
import SwiftUI

@MainActor // Basically add this to ensure everything is on the main thread to prevent background thread error
class SignUpViewModel: ObservableObject {
    @Published var password = ""
    @Published var errorMessage: String?
    
    init() {}
    
    func signUp(email: String, username: String, first_name: String, last_name: String, password: String, appEnvironment: AppEnvironment) async -> Bool {
        do {
            // Create user
            let user = try await appEnvironment.supabaseConnection.signUp(email: email, password: password, username: username)
            
            // Create profile
            try await appEnvironment.supabaseConnection.createProfile(username: username, first_name: first_name, last_name: last_name, location: nil)
            
            // Update the environment variable so the user data can be passed
            appEnvironment.appUser = AppUser(id: user.id.uuidString, email: user.email ?? "", username: username)
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("Error signing up: \(error.localizedDescription)")
            
            return false
        }
    }
}
