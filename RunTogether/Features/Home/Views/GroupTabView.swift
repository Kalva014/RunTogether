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
                    VStack(spacing: 16) {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                        
                        Button("Retry") {
                            Task {
                                try? await viewModel.fetchRunClubs(appEnvironment: appEnvironment)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                List {
                    ForEach(viewModel.runClubs) { club in
                        NavigationLink(destination: GroupDetailView(club: club)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(club.name)
                                    .font(.headline)
                                
                                if let description = club.description, !description.isEmpty {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
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
                .onChange(of: searchText) { oldValue, newValue in
                    if newValue.isEmpty {
                        isSearching = false
                        Task {
                            try? await viewModel.fetchRunClubs(appEnvironment: appEnvironment)
                        }
                    }
                }
                .refreshable {
                    try? await viewModel.fetchRunClubs(appEnvironment: appEnvironment)
                }
                .navigationTitle("Run Clubs")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingCreateClub = true }) {
                            Image(systemName: "plus")
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
