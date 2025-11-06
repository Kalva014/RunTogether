//
//  GroupDetailViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 10/9/25.
//
import Foundation

@MainActor
class GroupDetailViewModel: ObservableObject {
    struct MemberInfo: Identifiable {
        let id: UUID
        let username: String
        let profilePictureUrl: String?
    }
    
    @Published var clubMembers: [String] = []
    @Published var memberProfiles: [MemberInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isMember = false
    @Published var isOwner = false
    
    func checkMembership(appEnvironment: AppEnvironment, clubName: String) async {
        do {
            let myClubs = try await appEnvironment.supabaseConnection.listMyRunClubs()
            isMember = myClubs.contains(clubName)
        } catch {
            print("Error checking membership: \(error)")
        }
    }
    
    func checkOwnership(appEnvironment: AppEnvironment, ownerId: UUID?) async {
        guard let ownerId = ownerId,
              let currentUserId = appEnvironment.supabaseConnection.currentUserId else {
            isOwner = false
            return
        }
        isOwner = (ownerId == currentUserId)
    }
    
    func joinRunClub(appEnvironment: AppEnvironment, clubName: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await appEnvironment.supabaseConnection.joinRunClub(name: clubName)
            await checkMembership(appEnvironment: appEnvironment, clubName: clubName)
            await fetchClubMembers(appEnvironment: appEnvironment, clubName: clubName)
        } catch {
            errorMessage = "Failed to join run club: \(error.localizedDescription)"
            throw error
        }
    }
    
    func leaveRunClub(appEnvironment: AppEnvironment, clubName: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await appEnvironment.supabaseConnection.leaveRunClub(name: clubName)
            await checkMembership(appEnvironment: appEnvironment, clubName: clubName)
            await fetchClubMembers(appEnvironment: appEnvironment, clubName: clubName)
        } catch {
            errorMessage = "Failed to leave run club: \(error.localizedDescription)"
            throw error
        }
    }
    
    func deleteRunClub(appEnvironment: AppEnvironment, clubName: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await appEnvironment.supabaseConnection.deleteRunClub(name: clubName)
        } catch {
            errorMessage = "Failed to delete run club: \(error.localizedDescription)"
            throw error
        }
    }
    
    func fetchClubMembers(appEnvironment: AppEnvironment, clubName: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            clubMembers = try await appEnvironment.supabaseConnection.listRunClubMembers(name: clubName)
            
            // Fetch profile information for each member
            var profiles: [MemberInfo] = []
            for username in clubMembers {
                if let profile = try? await appEnvironment.supabaseConnection.getProfileByUsername(username: username) {
                    profiles.append(MemberInfo(id: profile.id, username: profile.username, profilePictureUrl: profile.profile_picture_url))
                }
            }
            memberProfiles = profiles
        } catch {
            errorMessage = "Failed to fetch club members: \(error.localizedDescription)"
        }
    }
}
