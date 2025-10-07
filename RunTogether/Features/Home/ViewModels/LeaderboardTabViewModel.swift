//
//  LeaderboardTabViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 10/2/25.
//

import Foundation
import Supabase
import SwiftUI

@MainActor
class LeaderboardTabViewModel: ObservableObject {
    @Published var leaderboardEntries: [GlobalLeaderboardEntry] = []
    @Published var profiles: [UUID: Profile] = [:] // Store profiles by user_id
    @Published var myStats: GlobalLeaderboardEntry?
    @Published var myProfile: Profile?
    @Published var myRank: Int?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Pagination
    @Published var currentPage = 0
    @Published var totalEntries = 0
    @Published var hasMorePages = true
    let pageSize = 20
    
    var totalPages: Int {
        guard totalEntries > 0 else { return 0 }
        return (totalEntries + pageSize - 1) / pageSize
    }
    
    var myDisplayName: String {
        if let myProfile = myProfile {
            if !myProfile.username.isEmpty {
                return myProfile.username
            } else if !myProfile.first_name.isEmpty && !myProfile.last_name.isEmpty {
                return "\(myProfile.first_name) \(myProfile.last_name)"
            } else if !myProfile.first_name.isEmpty {
                return myProfile.first_name
            }
        }
        return "You"
    }
    
    func displayName(for userId: UUID) -> String {
        if let profile = profiles[userId] {
            if !profile.username.isEmpty {
                return profile.username
            } else if !profile.first_name.isEmpty && !profile.last_name.isEmpty {
                return "\(profile.first_name) \(profile.last_name)"
            } else if !profile.first_name.isEmpty {
                return profile.first_name
            }
        }
        return "User \(userId.uuidString.prefix(8))"
    }
    
    func fetchLeaderboard(appEnvironment: AppEnvironment, page: Int? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let pageToFetch = page ?? currentPage
            let entries = try await appEnvironment.supabaseConnection.fetchGlobalLeaderboard(
                page: pageToFetch,
                pageSize: pageSize
            )
            
            if page != nil {
                // If specific page requested, replace entries
                leaderboardEntries = entries
                currentPage = pageToFetch
            } else {
                // Otherwise append for infinite scroll
                leaderboardEntries.append(contentsOf: entries)
            }
            
            // Fetch profiles for new entries
            await fetchProfilesForEntries(entries, appEnvironment: appEnvironment)
            
            hasMorePages = entries.count == pageSize
            isLoading = false
        } catch {
            errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func fetchProfilesForEntries(_ entries: [GlobalLeaderboardEntry], appEnvironment: AppEnvironment) async {
        for entry in entries {
            // Skip if we already have this profile
            if profiles[entry.user_id] != nil {
                continue
            }
            
            do {
                if let profile = try await appEnvironment.supabaseConnection.getProfileById(userId: entry.user_id) {
                    profiles[entry.user_id] = profile
                }
            } catch {
                print("Failed to fetch profile for user \(entry.user_id): \(error)")
            }
        }
    }
    
    func fetchTotalCount(appEnvironment: AppEnvironment) async {
        do {
            totalEntries = try await appEnvironment.supabaseConnection.fetchGlobalLeaderboardCount()
        } catch {
            print("Failed to fetch total count: \(error)")
        }
    }
    
    func fetchMyStats(appEnvironment: AppEnvironment) async {
        do {
            myStats = try await appEnvironment.supabaseConnection.fetchMyLeaderboardStats()
            myRank = try await appEnvironment.supabaseConnection.fetchMyLeaderboardRank()
            myProfile = try await appEnvironment.supabaseConnection.getProfile()
        } catch {
            print("Failed to fetch my stats: \(error)")
        }
    }
    
    func loadNextPage(appEnvironment: AppEnvironment) async {
        guard !isLoading && hasMorePages else { return }
        currentPage += 1
        await fetchLeaderboard(appEnvironment: appEnvironment)
    }
    
    func refresh(appEnvironment: AppEnvironment) async {
        currentPage = 0
        leaderboardEntries = []
        profiles = [:]
        hasMorePages = true
        
        async let leaderboardTask: () = fetchLeaderboard(appEnvironment: appEnvironment)
        async let statsTask: () = fetchMyStats(appEnvironment: appEnvironment)
        async let countTask: () = fetchTotalCount(appEnvironment: appEnvironment)
        
        await leaderboardTask
        await statsTask
        await countTask
    }
}
