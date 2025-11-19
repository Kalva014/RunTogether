//
//  RaceResultsView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/17/25.
//
// ==========================================
// MARK: - RaceResultsView.swift - COMPLETE
// ==========================================
import SwiftUI

struct RaceResultsView: View {
    let initialLeaderboard: [RunnerData]
    let playerTime: TimeInterval?
    let distance: String
    let stats: RaceStats?
    let raceId: UUID?
    
    var onExitToHome: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appEnvironment: AppEnvironment
    
    @State private var navigateHome: Bool = false
    @State private var showChat: Bool = false
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var resultsViewModel: RaceResultsViewModel
    
    init(leaderboard: [RunnerData], playerTime: TimeInterval?, distance: String, stats: RaceStats?, raceId: UUID?, onExitToHome: (() -> Void)? = nil) {
        self.initialLeaderboard = leaderboard
        self.playerTime = playerTime
        self.distance = distance
        self.stats = stats
        self.raceId = raceId
        self.onExitToHome = onExitToHome
        
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(raceId: raceId))
        _resultsViewModel = StateObject(wrappedValue: RaceResultsViewModel(
            initialLeaderboard: leaderboard,
            raceId: raceId,
            useMiles: stats?.useMiles ?? true
        ))
    }
    
    var body: some View {
        ZStack {
            // Full screen black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header (replaces navigation bar)
                customHeader
                
                // Scrollable content
                ScrollView {
                    VStack(spacing: 24) {
                        // Trophy and celebration
                        celebrationSection
                        
                        // Player stats card
                        if let stats = stats {
                            playerStatsCard(stats: stats)
                        }
                        
                        // Leaderboard
                        leaderboardSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            
            // Chat overlay
            if showChat {
                chatOverlay
            }
        }
        .navigationBarHidden(true)
        .background(
            NavigationLink(isActive: $navigateHome) {
                HomeView()
            } label: { EmptyView() }
                .hidden()
        )
        .onAppear {
            if raceId != nil {
                Task {
                    await resultsViewModel.startRealtimeUpdates(appEnvironment: appEnvironment)
                }
            }
        }
        .onDisappear {
            Task {
                await resultsViewModel.stopRealtimeUpdates()
                
                // Clean up race state to allow joining new races
                if let raceId = raceId {
                    // Ensure we've left the race channel properly
                    await appEnvironment.supabaseConnection.unsubscribeFromRaceBroadcasts()
                }
            }
        }
    }
    
    // MARK: - Custom Header
    private var customHeader: some View {
        HStack {
            Button(action: { navigateHome = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Home")
                        .font(.headline)
                }
                .foregroundColor(.orange)
            }
            
            Spacer()
            
            Text("Race Results")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            if raceId != nil {
                Button(action: { showChat.toggle() }) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }
            } else {
                // Invisible spacer to keep title centered
                Image(systemName: "message.fill")
                    .font(.system(size: 20))
                    .opacity(0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black)
    }
    
    // MARK: - Celebration Section
    private var celebrationSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Race Complete!")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            
            if let playerTime = playerTime {
                Text(formatTime(playerTime))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
            }
            
            Text(distance)
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Player Stats Card
    private func playerStatsCard(stats: RaceStats) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("\(stats.playerPlace)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    Text("Place")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .frame(height: 50)
                
                VStack(spacing: 4) {
                    Text("\(stats.totalRunners)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    Text("Runners")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if stats.playerPlace <= 3 {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                    Text("Top 3 Finish!")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(20)
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.2), Color.orange.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
    }
    
    // MARK: - Leaderboard Section
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Final Standings")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ForEach(Array(resultsViewModel.leaderboard.enumerated()), id: \.element.id) { index, runner in
                    resultRow(rank: index + 1, runner: runner)
                }
            }
        }
    }
    
    // MARK: - Result Row
    private func resultRow(rank: Int, runner: RunnerData) -> some View {
        HStack(spacing: 16) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor(rank: rank))
                    .frame(width: 50, height: 50)
                
                if rank <= 3 {
                    Image(systemName: rank == 1 ? "crown.fill" : "medal.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                } else {
                    Text("\(rank)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            // Profile picture
            ProfilePictureView(
                imageUrl: runner.profilePictureUrl,
                username: runner.name,
                size: 50
            )
            
            // Runner info
            VStack(alignment: .leading, spacing: 6) {
                Text(runner.name)
                    .font(.headline)
                    .foregroundColor(runner.name == "You" ? .orange : .white)
                
                HStack(spacing: 12) {
                    // Time
                    if let finishTime = runner.finishTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                            Text(formatTime(finishTime))
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                    }
                    
                    // Pace
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.caption)
                        Text(runner.pace)
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            runner.name == "You"
                ? Color.orange.opacity(0.15)
                : Color.white.opacity(0.05)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    runner.name == "You" ? Color.orange.opacity(0.5) : Color.clear,
                    lineWidth: runner.name == "You" ? 1 : 0
                )
        )
    }
    
    private func rankColor(rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return Color.white.opacity(0.2)
        }
    }
    
    // MARK: - Chat Overlay
    private var chatOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { showChat = false }
            
            ChatView(viewModel: chatViewModel, isPresented: $showChat)
        }
        .transition(.move(edge: .bottom))
        .animation(.spring(response: 0.3), value: showChat)
    }
    
    // MARK: - Helper
    private func formatTime(_ t: TimeInterval) -> String {
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        RaceResultsView(
            leaderboard: [
                RunnerData(name: "You", distance: 5000, pace: "5:30", finishTime: 1500, speed: nil),
                RunnerData(name: "Bre", distance: 5000, pace: "5:45", finishTime: 1520, speed: nil),
                RunnerData(name: "John", distance: 4800, pace: "6:00", finishTime: nil, speed: nil)
            ],
            playerTime: 1500,
            distance: "5.00 km",
            stats: RaceStats(
                playerName: "You",
                playerTime: 1500,
                playerPlace: 1,
                totalRunners: 3,
                raceDistanceMeters: 5000,
                useMiles: false
            ),
            raceId: UUID()
        )
        .environmentObject(AppEnvironment(
            appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"),
            supabaseConnection: SupabaseConnection()
        ))
    }
}
