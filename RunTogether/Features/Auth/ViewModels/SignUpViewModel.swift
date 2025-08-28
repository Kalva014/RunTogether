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

    func signUp(email: String, username: String, password: String) async {
        do {
            let user = try await supabaseConnection.signUp(email: email, password: password, username: username)
            appEnvironment.appUser = AppUser(id: user.id.uuidString, email: user.email ?? "", username: username)
        } catch {
            errorMessage = error.localizedDescription
            print("Error signing up: \(error.localizedDescription)")
        }
    }
}
