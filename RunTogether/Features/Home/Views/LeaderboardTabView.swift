//
//  LeaderboardView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/22/25.
//
import SwiftUI

struct LeaderboardTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel = LeaderboardTabViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // My Stats Card
                if let myStats = viewModel.myStats {
                    MyStatsCard(
                        stats: myStats,
                        rank: viewModel.myRank,
                        displayName: viewModel.myDisplayName,
                        profilePictureUrl: viewModel.myProfile?.profile_picture_url,
                        username: viewModel.myProfile?.username ?? "User"
                    )
                    .padding()
                }
                
                // Leaderboard List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(viewModel.leaderboardEntries.enumerated()), id: \.element.user_id) { index, entry in
                            NavigationLink(destination: ProfileDetailView(username: viewModel.username(for: entry.user_id))) {
                                LeaderboardRow(
                                    entry: entry,
                                    displayName: viewModel.displayName(for: entry.user_id),
                                    rank: (viewModel.currentPage * viewModel.pageSize) + index + 1,
                                    isCurrentUser: entry.user_id == appEnvironment.supabaseConnection.currentUserId,
                                    profilePictureUrl: viewModel.profilePictureUrl(for: entry.user_id),
                                    username: viewModel.username(for: entry.user_id)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            
                            // Load more when reaching last item
                            if index == viewModel.leaderboardEntries.count - 1 && viewModel.hasMorePages {
                                ProgressView()
                                    .onAppear {
                                        Task {
                                            await viewModel.loadNextPage(appEnvironment: appEnvironment)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await viewModel.refresh(appEnvironment: appEnvironment)
                }
            }
            .navigationTitle("Global Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .overlay {
                if viewModel.isLoading && viewModel.leaderboardEntries.isEmpty {
                    ProgressView("Loading leaderboard...")
                }
            }
            .overlay {
                if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                        Button("Retry") {
                            Task {
                                await viewModel.refresh(appEnvironment: appEnvironment)
                            }
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.refresh(appEnvironment: appEnvironment)
        }
    }
}

struct MyStatsCard: View {
    let stats: GlobalLeaderboardEntry
    let rank: Int?
    let displayName: String
    let profilePictureUrl: String?
    let username: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ProfilePictureView(imageUrl: profilePictureUrl, username: username, size: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.headline)
                    Text("Your Stats")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let rank = rank {
                    Text("#\(rank)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            
            HStack(spacing: 20) {
                StatItem(
                    title: "Races",
                    value: "\(Int(stats.total_races_completed ?? 0))"
                )
                
                Divider()
                
                StatItem(
                    title: "Distance",
                    value: String(format: "%.1f km", (stats.total_distance_covered ?? 0) / 1000)
                )
                
                Divider()
                
                StatItem(
                    title: "Top 3",
                    value: "\(stats.top_three_finishes ?? 0)"
                )
            }
            .frame(height: 60)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LeaderboardRow: View {
    let entry: GlobalLeaderboardEntry
    let displayName: String
    let rank: Int
    let isCurrentUser: Bool
    let profilePictureUrl: String?
    let username: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank Badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 40, height: 40)
                
                Text("\(rank)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // Profile Picture
            ProfilePictureView(imageUrl: profilePictureUrl, username: username, size: 44)
            
            // User Stats
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .foregroundColor(isCurrentUser ? .blue : .primary)
                
                HStack(spacing: 16) {
                    Label("\(Int(entry.total_races_completed ?? 0))", systemImage: "flag.fill")
                        .font(.caption)
                    
                    Label(String(format: "%.1f km", (entry.total_distance_covered ?? 0) / 1000), systemImage: "figure.run")
                        .font(.caption)
                    
                    if let topThree = entry.top_three_finishes, topThree > 0 {
                        Label("\(topThree)", systemImage: "trophy.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if isCurrentUser {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(isCurrentUser ? Color.blue.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentUser ? Color.blue : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle()) // Makes entire row tappable
    }
    
    var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

#Preview {
    LeaderboardTabView()
        .environmentObject(AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"), supabaseConnection: SupabaseConnection()))
}
