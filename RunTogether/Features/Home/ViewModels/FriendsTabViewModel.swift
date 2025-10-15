//
//  FriendsTabViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 10/15/25.
//

import Foundation
import SwiftUI

@MainActor
class FriendsTabViewModel: ObservableObject {
    @Published var friends: [Profile] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    func loadFriends(appEnvironment: AppEnvironment) async {
        guard let _ = appEnvironment.supabaseConnection.currentUserId else {
            errorMessage = "You must be signed in to view friends."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // 1️⃣ Get list of friend UUIDs from Supabase
            let friendIds = try await appEnvironment.supabaseConnection.listFriends()
            
            var loadedFriends: [Profile] = []
            
            // 2️⃣ Fetch each friend's profile
            for friendId in friendIds {
                if let profile = try? await appEnvironment.supabaseConnection.getProfileByUsername(username: friendId) {
                    loadedFriends.append(profile)
                }
            }
            
            self.friends = loadedFriends
        } catch {
            print("❌ Error loading friends: \(error)")
            self.errorMessage = "Failed to load friends."
        }
        
        isLoading = false
    }
}
