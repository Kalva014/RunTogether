//
//  SignUpViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/11/25.
//

import Foundation
import SwiftUI

class SignUpViewModel: ObservableObject {
    @Published var password = ""
    @Published var errorMessage: String?
    var appEnvironment: AppEnvironment
    
    lazy var supabaseConnection = SupabaseConnection()

    init(appEnvironment: AppEnvironment) {
        self.appEnvironment = appEnvironment
    }

    func signUp(email: String, username: String, first_name: String, last_name: String, password: String) async -> Bool {
        do {
            // Create user
            let user = try await supabaseConnection.signUp(email: email, password: password, username: username)
            appEnvironment.appUser = AppUser(id: user.id.uuidString, email: user.email ?? "", username: username)
            
            // Create profile
            try await supabaseConnection.createProfile(username: username, first_name: first_name, last_name: last_name, location: nil)
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("Error signing up: \(error.localizedDescription)")
            
            return false
        }
    }
}
