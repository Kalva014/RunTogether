//
//  ProfileTabViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/29/25.
//

import Foundation
import Supabase
import SwiftUI

@MainActor
class ProfileTabViewModel: ObservableObject {
    func editProfile(appEnvironment: AppEnvironment, username: String?, firstName: String?, lastName: String?, location: String?) async {
        do {
            try await appEnvironment.supabaseConnection.updateProfile(username: username, firstName: firstName, lastName: lastName, location: location)
        }
        catch {
            print("Error editing profile: \(error.localizedDescription)")
        }
    }
    
    func signOut(appEnvironment: AppEnvironment) async {
        do {
            try await appEnvironment.supabaseConnection.signOut()
            appEnvironment.appUser = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}
