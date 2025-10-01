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
    @Published var selectedClub: RunClub?
    @Published var clubMembers: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var searchTask: Task<Void, Never>?
    
    func createRunClub(appEnvironment: AppEnvironment, name: String, description: String) async throws {
        defer { isLoading = false }
        
        do {
            isLoading = true
            try await appEnvironment.supabaseConnection.createRunClub(name: name)
            // Update the local list after creating a new club
            try await fetchRunClubs(appEnvironment: appEnvironment)
        } catch {
            errorMessage = "Failed to create run club: \(error.localizedDescription)"
            throw error
        }
    }
    
    func joinRunClub(appEnvironment: AppEnvironment, clubName: String) async throws {
        defer { isLoading = false }
        
        do {
            isLoading = true
            try await appEnvironment.supabaseConnection.joinRunClub(name: clubName)
            // Refresh the list to show updated membership
            try await fetchRunClubs(appEnvironment: appEnvironment)
        } catch {
            errorMessage = "Failed to join run club: \(error.localizedDescription)"
            throw error
        }
    }
    
    func leaveRunClub(appEnvironment: AppEnvironment, clubName: String) async throws {
        defer { isLoading = false }
        
        do {
            isLoading = true
            try await appEnvironment.supabaseConnection.leaveRunClub(name: clubName)
            // Refresh the list to show updated membership
            try await fetchRunClubs(appEnvironment: appEnvironment)
            if selectedClub?.name == clubName {
                selectedClub = nil
                clubMembers = []
            }
        } catch {
            errorMessage = "Failed to leave run club: \(error.localizedDescription)"
            throw error
        }
    }
    
    func fetchRunClubs(appEnvironment: AppEnvironment) async throws {
        defer { isLoading = false }
        
        do {
            isLoading = true
            let clubNames = try await appEnvironment.supabaseConnection.listMyRunClubs()
            var clubs: [RunClub] = []
            
            // Fetch details for each club
            for clubName in clubNames {
                if let club = try? await appEnvironment.supabaseConnection.client
                    .from("Run_Clubs")
                    .select()
                    .eq("name", value: clubName)
                    .single()
                    .execute()
                    .value as? RunClub {
                    clubs.append(club)
                }
            }
            
            runClubs = clubs
        } catch {
            errorMessage = "Failed to fetch run clubs: \(error.localizedDescription)"
            throw error
        }
    }
    
    func searchRunClubs(appEnvironment: AppEnvironment, searchText: String) async {
        searchTask?.cancel()
        
        guard !searchText.isEmpty else {
            try? await fetchRunClubs(appEnvironment: appEnvironment)
            return
        }
        
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
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = "Search failed: \(error.localizedDescription)"
                }
            }
            
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }
    
    func fetchClubMembers(appEnvironment: AppEnvironment, clubName: String) async {
        defer { isLoading = false }
        
        do {
            isLoading = true
            clubMembers = try await appEnvironment.supabaseConnection.listRunClubMembers(name: clubName)
        } catch {
            errorMessage = "Failed to fetch club members: \(error.localizedDescription)"
        }
    }
}
