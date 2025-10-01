//
//  GroupTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/22/25.
//

import SwiftUI

struct GroupTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel: GroupTabViewModel
    @State private var searchText = ""
    @State private var showingCreateClub = false
    @State private var newClubName = ""
    @State private var newClubDescription = ""
    @State private var isSearching = false
    @State private var showDeleteConfirmation = false
    
    init() {
        _viewModel = StateObject(wrappedValue: GroupTabViewModel())
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                } else if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }
                
                List {
                    if let selectedClub = viewModel.selectedClub {
                        // Club detail view
                        Section(header: Text("Club Details")) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(selectedClub.name)
                                    .font(.title2)
                                    .bold()
                                
                                if let description = selectedClub.description, !description.isEmpty {
                                    Text(description)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                
                                if !viewModel.clubMembers.isEmpty {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Members (\(viewModel.clubMembers.count))")
                                            .font(.headline)
                                            .padding(.top, 8)
                                        
                                        ForEach(viewModel.clubMembers.prefix(10), id: \.self) { member in
                                            Text("• \(member)")
                                        }
                                        
                                        if viewModel.clubMembers.count > 10 {
                                            Text("and \(viewModel.clubMembers.count - 10) more...")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                VStack(spacing: 10) {
                                    // Show delete button if current user is the owner
                                    if let currentUser = appEnvironment.appUser, 
                                       selectedClub.owner?.uuidString == currentUser.id {
                                        Button(action: {
                                            showDeleteConfirmation = true
                                        }) {
                                            Text("Delete Club")
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(Color.red)
                                                .cornerRadius(10)
                                        }
                                        .buttonStyle(.borderless)
                                        .padding(.top, 10)
                                        .alert("Delete Club", isPresented: $showDeleteConfirmation) {
                                            Button("Delete", role: .destructive) {
                                                Task {
                                                    do {
                                                        try await viewModel.deleteRunClub(appEnvironment: appEnvironment, clubName: selectedClub.name)
                                                    } catch {
                                                        // Error handled by viewModel
                                                    }
                                                }
                                            }
                                            Button("Cancel", role: .cancel) {}
                                        } message: {
                                            Text("Are you sure you want to delete this club? This action cannot be undone.")
                                        }
                                    } else {
                                        // Show leave button for non-owners
                                        Button(action: {
                                            Task {
                                                do {
                                                    try await viewModel.leaveRunClub(appEnvironment: appEnvironment, clubName: selectedClub.name)
                                                } catch {
                                                    // Error handled by viewModel
                                                }
                                            }
                                        }) {
                                            Text("Leave Club")
                                                .foregroundColor(.red)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                        }
                                        .buttonStyle(.bordered)
                                        .padding(.top, 10)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        // List of clubs
                        ForEach(viewModel.runClubs) { club in
                            Button(action: {
                                viewModel.selectedClub = club
                                Task {
                                    await viewModel.fetchClubMembers(appEnvironment: appEnvironment, clubName: club.name)
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(club.name)
                                        .font(.headline)
                                    
                                    if let description = club.description, !description.isEmpty {
                                        Text(description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .searchable(text: $searchText, prompt: "Search Run Clubs")
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(of: .search) {
                    isSearching = true
                    Task {
                        await viewModel.searchRunClubs(appEnvironment: appEnvironment, searchText: searchText)
                    }
                }
                .onChange(of: searchText) { newValue in
                    if newValue.isEmpty {
                        isSearching = false
                        Task {
                            try? await viewModel.fetchRunClubs(appEnvironment: appEnvironment)
                        }
                    }
                }
                .navigationTitle("Run Clubs")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingCreateClub = true }) {
                            Image(systemName: "plus")
                        }
                    }
                    
                    if viewModel.selectedClub != nil {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Back") {
                                viewModel.selectedClub = nil
                            }
                        }
                    }
                }
            }
            .alert("Create New Run Club", isPresented: $showingCreateClub) {
                TextField("Club Name", text: $newClubName)
                TextField("Description (Optional)", text: $newClubDescription)
                
                Button("Create") {
                    Task {
                        do {
                            try await viewModel.createRunClub(
                                appEnvironment: appEnvironment,
                                name: newClubName,
                                description: newClubDescription
                            )
                            newClubName = ""
                            newClubDescription = ""
                        } catch {
                            // Error handled by viewModel
                        }
                    }
                }
                .disabled(newClubName.isEmpty)
                
                Button("Cancel", role: .cancel) {
                    newClubName = ""
                    newClubDescription = ""
                }
            } message: {
                Text("Enter a name and optional description for your new run club.")
            }
        }
        .task {
            do {
                try await viewModel.fetchRunClubs(appEnvironment: appEnvironment)
            } catch {
                // Error handled by viewModel
            }
        }
    }
}

#Preview {
    GroupTabView()
        .environmentObject(AppEnvironment(
            appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"),
            supabaseConnection: SupabaseConnection()
        ))
}
