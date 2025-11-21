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
            let profiles = try await appEnvironment.supabaseConnection.fetchFriendProfiles()
            let userIds = profiles.map { $0.id }
            let activeRaceMap = try await appEnvironment.supabaseConnection.fetchActiveRaces(for: userIds)
            
            self.friends = profiles.map { profile in
                FriendDisplay(
                    id: profile.id,
                    username: profile.username,
                    activeRaceId: activeRaceMap[profile.id],
                    profilePictureUrl: profile.profile_picture_url
                )
            }
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
