//
//  LeaderboardView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/22/25.
//
// ==========================================
// MARK: - LeaderboardTabView.swift
// ==========================================
// Updated LeaderboardTabView.swift with search:
import SwiftUI

struct LeaderboardTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel = LeaderboardTabViewModel()
    @State private var searchText = ""
    
    var filteredLeaderboard: [GlobalLeaderboardEntry] {
        if searchText.isEmpty {
            return viewModel.leaderboardEntries
        } else {
            return viewModel.leaderboardEntries.filter { entry in
                let username = viewModel.username(for: entry.user_id).lowercased()
                let displayName = viewModel.displayName(for: entry.user_id).lowercased()
                let search = searchText.lowercased()
                return username.contains(search) || displayName.contains(search)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    // Search bar
                    searchBar
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            if let myStats = viewModel.myStats {
                                myStatsCard(stats: myStats)
                            }
                            
                            leaderboardList
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        await viewModel.refresh(appEnvironment: appEnvironment)
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay {
                if viewModel.isLoading && viewModel.leaderboardEntries.isEmpty {
                    loadingView
                }
            }
        }
        .task {
            await viewModel.refresh(appEnvironment: appEnvironment)
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search users...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    private var leaderboardList: some View {
        VStack(spacing: 12) {
            ForEach(Array(filteredLeaderboard.enumerated()), id: \.element.user_id) { index, entry in
                NavigationLink(destination: ProfileDetailView(username: viewModel.username(for: entry.user_id))) {
                    leaderboardRow(
                        entry: entry,
                        rank: (viewModel.currentPage * viewModel.pageSize) + index + 1,
                        isCurrentUser: entry.user_id == appEnvironment.supabaseConnection.currentUserId
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                if index == filteredLeaderboard.count - 1 && viewModel.hasMorePages && searchText.isEmpty {
                    ProgressView()
                        .tint(.orange)
                        .onAppear {
                            Task {
                                await viewModel.loadNextPage(appEnvironment: appEnvironment)
                            }
                        }
                }
            }
            
            if filteredLeaderboard.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No users found")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
        }
    }
    
    // Keep all other methods the same...
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Leaderboard")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
            
            Text("Global Rankings")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    private func leaderboardRow(entry: GlobalLeaderboardEntry, rank: Int, isCurrentUser: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(rankColor(rank: rank))
                    .frame(width: 44, height: 44)
                
                if rank <= 3 {
                    Image(systemName: rank == 1 ? "crown.fill" : "medal.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                } else {
                    Text("\(rank)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            
            ProfilePictureView(
                imageUrl: viewModel.profilePictureUrl(for: entry.user_id),
                username: viewModel.username(for: entry.user_id),
                size: 50
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.displayName(for: entry.user_id))
                    .font(.headline)
                    .foregroundColor(isCurrentUser ? .orange : .white)
                
                HStack(spacing: 12) {
                    statBadge(icon: "flag.fill", value: "\(Int(entry.total_races_completed ?? 0))")
                    statBadge(icon: "figure.run", value: String(format: "%.0f km", (entry.total_distance_covered ?? 0) / 1000))
                    
                    if let topThree = entry.top_three_finishes, topThree > 0 {
                        statBadge(icon: "trophy.fill", value: "\(topThree)", color: .orange)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(isCurrentUser ? Color.orange.opacity(0.15) : Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrentUser ? Color.orange.opacity(0.5) : Color.clear, lineWidth: isCurrentUser ? 1 : 0)
        )
    }
    
    private func statBadge(icon: String, value: String, color: Color = .gray) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption)
        }
        .foregroundColor(color)
    }
    
    private func rankColor(rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return Color.white.opacity(0.2)
        }
    }
    
    private func myStatsCard(stats: GlobalLeaderboardEntry) -> some View {
        VStack(spacing: 16) {
            HStack {
                ProfilePictureView(
                    imageUrl: viewModel.myProfile?.profile_picture_url,
                    username: viewModel.myProfile?.username ?? "User",
                    size: 60
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.myDisplayName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if let rank = viewModel.myRank {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Rank #\(rank)")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            HStack(spacing: 0) {
                statItem(value: "\(Int(stats.total_races_completed ?? 0))", label: "Races")
                Divider().background(Color.white.opacity(0.2)).frame(height: 40)
                statItem(value: String(format: "%.1f", (stats.total_distance_covered ?? 0) / 1000), label: "Total km")
                Divider().background(Color.white.opacity(0.2)).frame(height: 40)
                statItem(value: "\(stats.top_three_finishes ?? 0)", label: "Top 3")
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.5), lineWidth: 1))
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)
            
            Text("Loading leaderboard...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.95))
    }
}

#Preview {
    LeaderboardTabView()
        .environmentObject(AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"), supabaseConnection: SupabaseConnection()))
}
