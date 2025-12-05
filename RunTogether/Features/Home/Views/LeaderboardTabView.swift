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
    @State private var hasLoaded = false
    
    var filteredRankedLeaderboard: [RankedLeaderboardEntry] {
        return viewModel.rankedLeaderboardEntries
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // My Ranked Stats Card
                            if let myRankedProfile = viewModel.myRankedProfile {
                                myRankedStatsCard(profile: myRankedProfile)
                            }
                            
                            rankDistributionCard
                            
                            // Ranked Leaderboard List
                            rankedLeaderboardList
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
            guard !hasLoaded else { return }
            hasLoaded = true
            await viewModel.refresh(appEnvironment: appEnvironment)
        }
    }
    
    
    // Keep all other methods the same...
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: ResponsiveLayout.titleFontSize * 0.8))
                    .foregroundColor(.orange)
                
                Text("Ranked")
                    .font(.system(size: ResponsiveLayout.titleFontSize, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Competitive Standings")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .responsiveHorizontalPadding()
        .padding(.top, max(60, ResponsiveLayout.safeAreaTopPadding + 16))
        .padding(.bottom, ResponsiveLayout.sectionSpacing)
    }
    
    private var rankedLeaderboardList: some View {
        VStack(spacing: 12) {
            ForEach(Array(filteredRankedLeaderboard.enumerated()), id: \.element.user_id) { index, entry in
                NavigationLink(destination: ProfileDetailView(username: viewModel.username(for: entry.user_id))) {
                    rankedLeaderboardRow(
                        entry: entry,
                        position: index + 1,
                        isCurrentUser: entry.user_id == appEnvironment.supabaseConnection.currentUserId
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if filteredRankedLeaderboard.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No ranked players yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Play a ranked race to appear here!")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
        }
    }
    
    private func rankedLeaderboardRow(entry: RankedLeaderboardEntry, position: Int, isCurrentUser: Bool) -> some View {
        HStack(spacing: 16) {
            // Position Badge
            ZStack {
                Circle()
                    .fill(rankColor(rank: position))
                    .frame(width: 44, height: 44)
                
                if position <= 3 {
                    Image(systemName: position == 1 ? "crown.fill" : "medal.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                } else {
                    Text("\(position)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            
            // Profile Picture
            ProfilePictureView(
                imageUrl: viewModel.profilePictureUrl(for: entry.user_id),
                username: viewModel.username(for: entry.user_id),
                size: 50
            )
            
            // User Info
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.displayName(for: entry.user_id))
                    .font(.headline)
                    .foregroundColor(isCurrentUser ? .orange : .white)
                
                // Rank Display
                HStack(spacing: 8) {
                    Text(rankEmoji(for: entry.tier))
                        .font(.caption)
                    
                    Text(entry.displayString)
                        .font(.subheadline)
                        .foregroundColor(.orange)
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
    
    private func myRankedStatsCard(profile: RankedProfile) -> some View {
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
                    
                    HStack(spacing: 8) {
                        Text(rankEmoji(for: profile.tier))
                        Text(profile.displayString)
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    
                    if let position = viewModel.myRankedPosition {
                        HStack(spacing: 4) {
                            Image(systemName: "number")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text("Position #\(position)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            HStack(spacing: 0) {
                statItem(value: "\(profile.top_3_finishes ?? 0)", label: "Top 3")
                Divider().background(Color.white.opacity(0.2)).frame(height: 40)
                statItem(value: "\(profile.total_races ?? 0)", label: "Races")
                Divider().background(Color.white.opacity(0.2)).frame(height: 40)
                if (profile.total_races ?? 0) > 0 {
                    let top3 = Double(profile.top_3_finishes ?? 0)
                    let total = Double(profile.total_races ?? 0)
                    let top3Rate = (top3 / total) * 100
                    statItem(value: String(format: "%.0f%%", top3Rate), label: "Top 3 Rate")
                } else {
                    statItem(value: "0%", label: "Top 3 Rate")
                }
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
    
    private func rankEmoji(for tier: RankTier) -> String {
        switch tier {
        case .bronze: return "🥉"
        case .silver: return "🥈"
        case .gold: return "🥇"
        case .platinum: return "💠"
        case .diamond: return "💎"
        case .champion: return "👑"
        }
    }
    
    
    private func rankColor(rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return Color.white.opacity(0.2)
        }
    }
    
    private var rankDistributionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rank Breakdown")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Share of players in each tier")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("\(viewModel.totalRankedPlayers) players")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                ForEach(viewModel.rankDistributionSlices) { slice in
                    rankDistributionRow(slice)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func rankDistributionRow(_ slice: LeaderboardTabViewModel.RankDistributionSlice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(slice.tier.emoji)
                Text(slice.tier.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(String(format: "%.0f%%", slice.percentage))
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 10)
                    
                    Capsule()
                        .fill(tierColor(for: slice.tier))
                        .frame(width: geometry.size.width * CGFloat(min(slice.percentage, 100) / 100.0),
                               height: 10)
                }
            }
            .frame(height: 10)
            
            Text(slice.tier.descriptor)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
    
    private func tierColor(for tier: RankTier) -> Color {
        switch tier {
        case .bronze: return Color(red: 156/255, green: 120/255, blue: 72/255)
        case .silver: return Color(red: 192/255, green: 192/255, blue: 192/255)
        case .gold: return Color(red: 255/255, green: 215/255, blue: 0/255)
        case .platinum: return Color(red: 142/255, green: 202/255, blue: 230/255)
        case .diamond: return Color(red: 135/255, green: 206/255, blue: 250/255)
        case .champion: return Color(red: 255/255, green: 99/255, blue: 71/255)
        }
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
