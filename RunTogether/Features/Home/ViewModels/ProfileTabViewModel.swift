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
    @Published var myStats: GlobalLeaderboardEntry?
    @Published var isLoadingStats = false
    
    func loadStats(appEnvironment: AppEnvironment) async {
        isLoadingStats = true
        do {
            myStats = try await appEnvironment.supabaseConnection.fetchMyLeaderboardStats()
        } catch {
            // Only log non-cancellation errors
            if (error as NSError).code != NSURLErrorCancelled {
                print("Failed to load profile stats: \(error)")
            }
        }
        isLoadingStats = false
    }
    
    func editProfile(appEnvironment: AppEnvironment, username: String?, firstName: String?, lastName: String?, location: String?, profilePictureUrl: String? = nil) async {
        do {
            try await appEnvironment.supabaseConnection.updateProfile(username: username, firstName: firstName, lastName: lastName, location: location, profilePictureUrl: profilePictureUrl)
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
