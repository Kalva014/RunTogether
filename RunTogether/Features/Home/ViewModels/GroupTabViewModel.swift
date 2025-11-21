//
//  GroupTabViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 10/1/25.
//
//
//  GroupTabViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 10/1/25.
//
import Foundation
import Supabase
import SwiftUI

@MainActor
class GroupTabViewModel: ObservableObject {
    @Published var runClubs: [RunClub] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var searchTask: Task<Void, Never>?
    
    func createRunClub(appEnvironment: AppEnvironment, name: String, description: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await appEnvironment.supabaseConnection.createRunClub(name: name, description: description)
            // Update the local list after creating a new club
            try await fetchRunClubs(appEnvironment: appEnvironment)
        } catch {
            errorMessage = "Failed to create run club: \(error.localizedDescription)"
            throw error
        }
    }
    
    func fetchRunClubs(appEnvironment: AppEnvironment) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let clubNames = try await appEnvironment.supabaseConnection.listMyRunClubs()
            print("📋 User is member of clubs: \(clubNames)")
            
            guard !clubNames.isEmpty else {
                runClubs = []
                errorMessage = nil
                return
            }
            
            let fetchedClubs = try await appEnvironment.supabaseConnection.fetchRunClubs(named: clubNames)
            let clubsByName = Dictionary(uniqueKeysWithValues: fetchedClubs.map { ($0.name, $0) })
            
            runClubs = clubNames.compactMap { clubsByName[$0] }
            errorMessage = nil
            print("✅ Total clubs loaded: \(runClubs.count)")
        } catch {
            print("❌ Error in fetchRunClubs: \(error)")
            errorMessage = "Failed to fetch run clubs: \(error.localizedDescription)"
            throw error
        }
    }
    
    func fetchAllRunClubs(appEnvironment: AppEnvironment) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            runClubs = try await appEnvironment.supabaseConnection.listRunClubs()
            errorMessage = nil
            print("✅ Fetched all clubs: \(runClubs.count)")
        } catch {
            print("❌ Error fetching all clubs: \(error)")
            errorMessage = "Failed to fetch clubs: \(error.localizedDescription)"
            throw error
        }
    }
    
    @MainActor
    func searchRunClubs(appEnvironment: AppEnvironment, searchText: String) async {
        guard !searchText.isEmpty else {
            try? await fetchRunClubs(appEnvironment: appEnvironment)
            return
        }
        
        searchTask?.cancel()
        
        searchTask = Task {
            do {
                isLoading = true
                let clubs: [RunClub] = try await appEnvironment.supabaseConnection.client
                    .from("Run_Clubs")
                    .select()
                    .ilike("name", pattern: "%\(searchText)%")
                    .execute()
                    .value ?? []
                
                if !Task.isCancelled {
                    runClubs = clubs
                    errorMessage = nil
                    print("🔍 Search results: \(clubs.count)")
                }
            } catch {
                if !Task.isCancelled {
                    print("❌ Search error: \(error)")
                    errorMessage = "Search failed: \(error.localizedDescription)"
                }
            }
            
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }
}
