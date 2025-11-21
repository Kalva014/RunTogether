//
//  ProfileDetailViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 10/7/25.
//
import Foundation

@MainActor
class ProfileDetailViewModel: ObservableObject {
    @Published var userId: UUID?
    @Published var isFriend: Bool = false
    
    func addFriend(appEnvironment: AppEnvironment, username: String) async {
        do {
            try await appEnvironment.supabaseConnection.addFriend(username: username)
            isFriend = true
        } catch {
            print("Error adding friend: \(error.localizedDescription)")
        }
    }
    
    func removeFriend(appEnvironment: AppEnvironment, username: String) async {
        do {
            try await appEnvironment.supabaseConnection.removeFriend(username: username)
            isFriend = false
        } catch {
            print("Error removing friend: \(error.localizedDescription)")
        }
    }
    
    func getInfo(appEnvironment: AppEnvironment, username: String) async -> Profile? {
        do {
            let userInfo = try await appEnvironment.supabaseConnection.getProfileByUsername(username: username)
            if let userInfo = userInfo {
                self.userId = userInfo.id
            }
            return userInfo
        } catch {
            print("Error getting info of profile: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getPersonalRunClubs(appEnvironment: AppEnvironment, username: String) async -> [String] {
        guard let userId = userId else {
            print("User ID not set")
            return []
        }
        
        do {
            return try await appEnvironment.supabaseConnection.listSpecificUserRunClubs(specificId: userId)
        } catch {
            print("Error getting run clubs: \(error.localizedDescription)")
            return []
        }
    }
    
    func getStats(appEnvironment: AppEnvironment, username: String) async -> GlobalLeaderboardEntry? {
        guard let userId = userId else {
            print("User ID not set")
            return nil
        }
        
        do {
            return try await appEnvironment.supabaseConnection.fetchSpecificUserLeaderboardStats(specificUserId: userId)
        } catch {
            print("Error getting stats: \(error.localizedDescription)")
            return nil
        }
    }
    
    func refreshFriendStatus(appEnvironment: AppEnvironment, username: String) async {
        do {
            let friends = try await appEnvironment.supabaseConnection.listFriends()
            isFriend = friends.contains(username)
        } catch {
            print("Error checking friend status: \(error)")
            isFriend = false
        }
    }
}
