//
//  ProfileDetailView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 10/7/25.
//
import SwiftUI

struct ProfileDetailView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel = ProfileDetailViewModel()
    
    let username: String
    
    @State private var profile: Profile?
    @State private var stats: GlobalLeaderboardEntry?
    @State private var runClubs: [String] = []
    @State private var isLoading = true
    @State private var isFriend = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading profile...")
                        .padding()
                } else if let profile = profile {
                    // Profile Header
                    VStack(spacing: 8) {
                        Text("@\(profile.username)")
                            .font(.title)
                            .bold()
                        
                        Text("\(profile.first_name) \(profile.last_name)")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        if let location = profile.location {
                            Text(location)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    // Friend Actions
                    HStack(spacing: 16) {
                        if isFriend {
                            Button(action: {
                                Task {
                                    await removeFriend()
                                }
                            }) {
                                Label("Remove Friend", systemImage: "person.fill.xmark")
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                        } else {
                            Button(action: {
                                Task {
                                    await addFriend()
                                }
                            }) {
                                Label("Add Friend", systemImage: "person.fill.badge.plus")
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Stats Section
                    if let stats = stats {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Statistics")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                StatRow(
                                    icon: "flag.checkered",
                                    label: "Races Completed",
                                    value: "\(Int(stats.total_races_completed ?? 0))"
                                )
                                
                                StatRow(
                                    icon: "arrow.left.and.right",
                                    label: "Total Distance",
                                    value: String(format: "%.2f mi", stats.total_distance_covered ?? 0)
                                )
                                
                                StatRow(
                                    icon: "trophy",
                                    label: "Top 3 Finishes",
                                    value: "\(stats.top_three_finishes ?? 0)"
                                )
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Run Clubs Section
                    if !runClubs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Run Clubs")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(runClubs, id: \.self) { club in
                                    HStack {
                                        Image(systemName: "figure.run")
                                            .foregroundColor(.blue)
                                        Text(club)
                                            .font(.body)
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Run Clubs")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Text("Not a member of any run clubs")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    Text("Profile not found")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadProfileData()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadProfileData() async {
        isLoading = true
        
        // Load profile info
        profile = await viewModel.getInfo(appEnvironment: appEnvironment, username: username)
        
        guard profile != nil else {
            isLoading = false
            errorMessage = "Could not load profile"
            showError = true
            return
        }
        
        // Load stats
        stats = await viewModel.getStats(appEnvironment: appEnvironment, username: username)
        
        // Load run clubs
        runClubs = await viewModel.getPersonalRunClubs(appEnvironment: appEnvironment, username: username)
        
        // Check if already a friend
        await checkFriendStatus()
        
        isLoading = false
    }
    
    private func checkFriendStatus() async {
        do {
            let friends = try await appEnvironment.supabaseConnection.listFriends()
            isFriend = friends.contains(username)
        } catch {
            print("Error checking friend status: \(error)")
        }
    }
    
    private func addFriend() async {
        await viewModel.addFriend(appEnvironment: appEnvironment, username: username)
        await checkFriendStatus()
    }
    
    private func removeFriend() async {
        await viewModel.removeFriend(appEnvironment: appEnvironment, username: username)
        await checkFriendStatus()
    }
}

// MARK: - Supporting Views

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(label)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .bold()
        }
    }
}

#Preview {
    NavigationStack {
        ProfileDetailView(username: "TheCeo")
            .environmentObject(AppEnvironment(
                appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"),
                supabaseConnection: SupabaseConnection()
            ))
    }
}
