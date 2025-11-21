import Foundation
import SwiftUI

@MainActor
class FriendsTabViewModel: ObservableObject {
    struct FriendDisplay: Identifiable {
        let id: UUID
        let username: String
        let activeRaceId: UUID?
        let profilePictureUrl: String?
    }
    
@Published var friends: [FriendDisplay] = []
@Published var isLoading: Bool = false
@Published var errorMessage: String? = nil
@Published var searchResults: [Profile] = []
@Published var isSearching: Bool = false
@Published var searchErrorMessage: String? = nil
    
    func loadFriends(appEnvironment: AppEnvironment) async {
        guard let _ = appEnvironment.supabaseConnection.currentUserId else {
            errorMessage = "You must be signed in to view friends."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let friendIds = try await appEnvironment.supabaseConnection.listFriends()
            var loadedFriends: [FriendDisplay] = []
            
            for friendId in friendIds {
                // Get the profile info
                guard let profile = try? await appEnvironment.supabaseConnection.getProfileByUsername(username: friendId) else { continue }
                
                // Get active race if any
                let raceId = try? await appEnvironment.supabaseConnection.getActiveRaceForUser(userId: profile.id)
                
                let display = FriendDisplay(id: profile.id, username: profile.username, activeRaceId: raceId, profilePictureUrl: profile.profile_picture_url)
                loadedFriends.append(display)
            }
            
            self.friends = loadedFriends
        } catch {
            print("❌ Error loading friends: \(error)")
            self.errorMessage = "Failed to load friends."
        }
        
        isLoading = false
    }
    
    func searchUsers(appEnvironment: AppEnvironment, query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            searchErrorMessage = nil
            isSearching = false
            return
        }
        
        isSearching = true
        searchErrorMessage = nil
        
        do {
            let profiles: [Profile] = try await appEnvironment.supabaseConnection.client
                .from("Profiles")
                .select()
                .ilike("username", pattern: "%\(trimmedQuery)%")
                .limit(20)
                .execute()
                .value ?? []
            
            let currentUserId = appEnvironment.supabaseConnection.currentUserId
            
            self.searchResults = profiles.filter { $0.id != currentUserId }
        } catch {
            print("❌ Error searching users: \(error)")
            searchErrorMessage = "Failed to search users."
            searchResults = []
        }
        
        isSearching = false
    }
    
    func clearSearchState() {
        searchResults = []
        searchErrorMessage = nil
        isSearching = false
    }
}
