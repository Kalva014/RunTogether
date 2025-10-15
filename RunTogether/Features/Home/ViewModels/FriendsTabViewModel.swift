import Foundation
import SwiftUI

@MainActor
class FriendsTabViewModel: ObservableObject {
    struct FriendDisplay: Identifiable {
        let id: UUID
        let username: String
        let activeRaceId: UUID?
    }
    
    @Published var friends: [FriendDisplay] = []
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
            let friendIds = try await appEnvironment.supabaseConnection.listFriends()
            var loadedFriends: [FriendDisplay] = []
            
            for friendId in friendIds {
                // Get the profile info
                guard let profile = try? await appEnvironment.supabaseConnection.getProfileByUsername(username: friendId) else { continue }
                
                // Get active race if any
                let raceId = try? await appEnvironment.supabaseConnection.getActiveRaceForUser(userId: profile.id)
                
                let display = FriendDisplay(id: profile.id, username: profile.username, activeRaceId: raceId)
                loadedFriends.append(display)
            }
            
            self.friends = loadedFriends
        } catch {
            print("❌ Error loading friends: \(error)")
            self.errorMessage = "Failed to load friends."
        }
        
        isLoading = false
    }
}
