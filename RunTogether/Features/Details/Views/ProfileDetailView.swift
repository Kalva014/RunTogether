//
//  ProfileDetailView.swift
//  RunTogether
//
// ==========================================
// MARK: - ProfileDetailView.swift - COMPLETE WITH SCREEN FIX
// ==========================================
import SwiftUI

struct ProfileDetailView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel = ProfileDetailViewModel()
    
    let username: String
    
    @State private var profile: Profile?
    @State private var stats: GlobalLeaderboardEntry?
    @State private var runClubs: [String] = []
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Background - FIRST with ignoresSafeArea
            Color.black
                .ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if let profile = profile {
                ScrollView {
                    VStack(spacing: 24) {
                        profileHeader(profile: profile)
                        friendActionButton
                        
                        if let stats = stats {
                            statsSection(stats: stats)
                        }
                        
                        runClubsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            } else {
                errorStateView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("@\(username)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadProfileData()
        }
    }
    
    // MARK: - Profile Header
    private func profileHeader(profile: Profile) -> some View {
        VStack(spacing: 16) {
            ProfilePictureView(
                imageUrl: profile.profile_picture_url,
                username: profile.username,
                size: 100
            )
            
            VStack(spacing: 8) {
                Text("@\(profile.username)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("\(profile.first_name) \(profile.last_name)")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                if let location = profile.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(location)
                            .font(.subheadline)
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Friend Action Button
    private var friendActionButton: some View {
        Button(action: {
            Task {
                if viewModel.isFriend {
                    await removeFriend()
                } else {
                    await addFriend()
                }
            }
        }) {
            HStack {
                Image(systemName: viewModel.isFriend ? "person.fill.xmark" : "person.fill.badge.plus")
                Text(viewModel.isFriend ? "Remove Friend" : "Add Friend")
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .foregroundColor(viewModel.isFriend ? .white : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.isFriend ? Color.red.opacity(0.8) : Color.orange)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Stats Section
    private func statsSection(stats: GlobalLeaderboardEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                statRow(
                    icon: "flag.checkered",
                    label: "Races Completed",
                    value: "\(Int(stats.total_races_completed ?? 0))",
                    color: .orange
                )
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                statRow(
                    icon: "arrow.left.and.right",
                    label: "Total Distance",
                    value: String(format: "%.2f km", (stats.total_distance_covered ?? 0) / 1000),
                    color: .orange
                )
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                statRow(
                    icon: "trophy.fill",
                    label: "Top 3 Finishes",
                    value: "\(stats.top_three_finishes ?? 0)",
                    color: .orange
                )
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
    
    private func statRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Run Clubs Section
    private var runClubsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Run Clubs")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if runClubs.isEmpty {
                emptyClubsView
            } else {
                VStack(spacing: 12) {
                    ForEach(runClubs, id: \.self) { club in
                        clubRow(club: club)
                    }
                }
            }
        }
    }
    
    private func clubRow(club: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "figure.run")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }
            
            Text(club)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var emptyClubsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Not a member of any run clubs")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)
            
            Text("Loading profile...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error State
    private var errorStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Profile Not Found")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("We couldn't find this user's profile")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    private func loadProfileData() async {
        isLoading = true
        
        profile = await viewModel.getInfo(appEnvironment: appEnvironment, username: username)
        
        guard profile != nil else {
            isLoading = false
            errorMessage = "Could not load profile"
            showError = true
            return
        }
        
        stats = await viewModel.getStats(appEnvironment: appEnvironment, username: username)
        runClubs = await viewModel.getPersonalRunClubs(appEnvironment: appEnvironment, username: username)
        await viewModel.refreshFriendStatus(appEnvironment: appEnvironment, username: username)
        
        isLoading = false
    }
    
    private func addFriend() async {
        await viewModel.addFriend(appEnvironment: appEnvironment, username: username)
    }
    
    private func removeFriend() async {
        await viewModel.removeFriend(appEnvironment: appEnvironment, username: username)
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
