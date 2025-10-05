//
//  LeaderboardTabViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 10/2/25.
//
//
//import Foundation
//import Supabase
//import SwiftUI
//
//@MainActor
//class LeaderboardTabViewModel: ObservableObject {
//    func fetchLeaderboard(appEnvironment: AppEnvironment, ) async throws {
//        appEnvironment.supabaseConnection.fetchGlobalLeaderboard()
//    }
//    
//    func fetchMyLeaderboard(appEnvironment: AppEnvironment) async throws {
//        appEnvironment.supabaseConnection.fetchMyLeaderboardStats()
//    }
//    
//    func searchLeaderboard(username: String) {
//        
//    }
//}



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
    @Published var myStats: GlobalLeaderboardEntry?
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
            
            hasMorePages = entries.count == pageSize
            isLoading = false
        } catch {
            errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
            isLoading = false
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
        hasMorePages = true
        
        async let leaderboardTask: () = fetchLeaderboard(appEnvironment: appEnvironment)
        async let statsTask: () = fetchMyStats(appEnvironment: appEnvironment)
        async let countTask: () = fetchTotalCount(appEnvironment: appEnvironment)
        
        await leaderboardTask
        await statsTask
        await countTask
    }
}
