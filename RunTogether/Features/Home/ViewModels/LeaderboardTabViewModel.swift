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
    @Published var rankedLeaderboardEntries: [RankedLeaderboardEntry] = []
    @Published var profiles: [UUID: Profile] = [:] // Store profiles by user_id
    @Published var myStats: GlobalLeaderboardEntry?
    @Published var myRankedProfile: RankedProfile?
    @Published var myProfile: Profile?
    @Published var myRank: Int?
    @Published var myRankedPosition: Int?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Leaderboard type - Always showing ranked
    @Published var showRanked = true // Always show ranked
    @Published var showFriendsOnly = false // Toggle between global and friends (future feature)
    
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
    
    func profilePictureUrl(for userId: UUID) -> String? {
        return profiles[userId]?.profile_picture_url
    }
    
    func username(for userId: UUID) -> String {
        return profiles[userId]?.username ?? "User"
    }
    
    struct RankDistributionSlice: Identifiable {
        let tier: RankTier
        let count: Int
        let percentage: Double
        
        var id: String { tier.rawValue }
    }
    
    var totalRankedPlayers: Int {
        rankedLeaderboardEntries.count
    }
    
    var rankDistributionSlices: [RankDistributionSlice] {
        guard totalRankedPlayers > 0 else {
            return RankTier.allCases.map { RankDistributionSlice(tier: $0, count: 0, percentage: 0) }
        }
        
        var counts: [RankTier: Int] = [:]
        for entry in rankedLeaderboardEntries {
            let tier = entry.tier
            counts[tier, default: 0] += 1
        }
        
        return RankTier.allCases.map { tier in
            let count = counts[tier] ?? 0
            let percent = (Double(count) / Double(totalRankedPlayers)) * 100.0
            return RankDistributionSlice(tier: tier, count: count, percentage: percent)
        }
    }
    
    func fetchLeaderboard(appEnvironment: AppEnvironment, page: Int? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let pageToFetch = page ?? currentPage
            
            if showRanked {
                // Fetch ranked leaderboard
                if showFriendsOnly {
                    let entries = try await appEnvironment.supabaseConnection.fetchFriendsRankedLeaderboard()
                    rankedLeaderboardEntries = entries
                    hasMorePages = false // Friends list is not paginated
                } else {
                    let entries = try await appEnvironment.supabaseConnection.fetchRankedLeaderboard(
                        page: pageToFetch,
                        pageSize: pageSize
                    )
                    
                    if page != nil {
                        rankedLeaderboardEntries = entries
                        currentPage = pageToFetch
                    } else {
                        rankedLeaderboardEntries.append(contentsOf: entries)
                    }
                    
                    hasMorePages = entries.count == pageSize
                }
                
                // Fetch profiles for ranked entries
                await fetchProfilesForRankedEntries(rankedLeaderboardEntries, appEnvironment: appEnvironment)
            } else {
                // Fetch casual leaderboard
                let entries = try await appEnvironment.supabaseConnection.fetchGlobalLeaderboard(
                    page: pageToFetch,
                    pageSize: pageSize
                )
                
                if page != nil {
                    leaderboardEntries = entries
                    currentPage = pageToFetch
                } else {
                    leaderboardEntries.append(contentsOf: entries)
                }
                
                // Fetch profiles for new entries
                await fetchProfilesForEntries(entries, appEnvironment: appEnvironment)
                
                hasMorePages = entries.count == pageSize
            }
            
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
    
    func fetchProfilesForRankedEntries(_ entries: [RankedLeaderboardEntry], appEnvironment: AppEnvironment) async {
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
            
            // Also fetch ranked profile and position
            myRankedProfile = try await appEnvironment.supabaseConnection.getRankedProfile()
            myRankedPosition = try await appEnvironment.supabaseConnection.getMyRankedPosition()
        } catch {
            if error.isCancelledRequest {
                print("⚠️ fetchMyStats cancelled")
            } else {
                print("Failed to fetch my stats: \(error)")
            }
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
        rankedLeaderboardEntries = []
        profiles = [:]
        hasMorePages = true
        
        // Use TaskGroup to prevent automatic cancellation
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await self.fetchLeaderboard(appEnvironment: appEnvironment)
            }
            group.addTask { @MainActor in
                await self.fetchMyStats(appEnvironment: appEnvironment)
            }
            group.addTask { @MainActor in
                await self.fetchTotalCount(appEnvironment: appEnvironment)
            }
            
            // Wait for all tasks to complete
            await group.waitForAll()
        }
    }
    
    /// Switch between ranked and casual leaderboards
    func toggleLeaderboardType(appEnvironment: AppEnvironment) async {
        showRanked.toggle()
        await refresh(appEnvironment: appEnvironment)
    }
    
    /// Switch between global and friends leaderboards
    func toggleFriendsOnly(appEnvironment: AppEnvironment) async {
        showFriendsOnly.toggle()
        await refresh(appEnvironment: appEnvironment)
    }
    
    /// Get rank display string for a user
    func rankDisplay(for userId: UUID) -> String? {
        guard let rankedEntry = rankedLeaderboardEntries.first(where: { $0.user_id == userId }) else {
            return nil
        }
        return rankedEntry.displayString
    }
    
    /// Get user's rank display
    var myRankDisplay: String? {
        return myRankedProfile?.displayString
    }
}
