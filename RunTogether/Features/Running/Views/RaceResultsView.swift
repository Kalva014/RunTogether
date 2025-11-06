//
//  RaceResultsView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/17/25.
//

import SwiftUI

struct RaceResultsView: View {
    let initialLeaderboard: [RunnerData]
    let playerTime: TimeInterval?
    let distance: String
    let stats: RaceStats?
    let raceId: UUID?
    
    // A callback to handle the navigation action
    var onExitToHome: (() -> Void)? = nil
    
    // An Environment variable to dismiss the view
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appEnvironment: AppEnvironment
    
    // Programmatic navigation to Home
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
            VStack(spacing: 16) {
                HStack {
                    Button(action: { navigateHome = true }) {
                        Text("Home")
                    }.buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    // Chat button (only show if raceId exists)
                    if raceId != nil {
                        Button(action: {
                            showChat.toggle()
                        }) {
                            HStack {
                                Image(systemName: "message.fill")
                                Text("Chat")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            
            VStack(spacing: 4) {
                Text("Race Results")
                    .font(.largeTitle).bold()
                if let playerTime = playerTime {
                    Text("Your time: \(formatTime(playerTime)) mins")
                        .font(.headline)
                        .foregroundColor(.yellow)
                }
                Text(distance)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let stats = stats {
                    Text("Place: #\(stats.playerPlace) of \(stats.totalRunners)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
            
            List {
                ForEach(Array(resultsViewModel.leaderboard.enumerated()), id: \.element.id) { index, runner in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(index + 1)")
                                .frame(width: 24, alignment: .leading)
                                .foregroundColor(.yellow)
                                .font(.headline)
                            
                            ProfilePictureView(imageUrl: runner.profilePictureUrl, username: runner.name, size: 36)
                            
                            Text(runner.name)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 16) {
                            // Time column
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let finishTime = runner.finishTime {
                                    Text(formatTime(finishTime))
                                        .monospacedDigit()
                                        .font(.subheadline)
                                } else {
                                    Text("N/A")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                            }
                            
                            // Pace column
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Avg Pace")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(runner.pace)
                                    .monospacedDigit()
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                // Refresh is handled by realtime updates
            }
            }
            .padding(.horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .background(
                NavigationLink(isActive: $navigateHome) {
                    HomeView()
                } label: { EmptyView() }
                    .hidden()
            )
            
            // Chat overlay
            if showChat {
                ChatView(viewModel: chatViewModel, isPresented: $showChat)
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
        }
        .onAppear {
            // Start realtime updates if raceId exists
            if raceId != nil {
                Task {
                    await resultsViewModel.startRealtimeUpdates(appEnvironment: appEnvironment)
                }
            }
        }
        .onDisappear {
            Task {
                await resultsViewModel.stopRealtimeUpdates()
            }
        }
    }
    
    private func formatTime(_ t: TimeInterval) -> String {
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


#Preview {
    RaceResultsView(
        leaderboard: [
            RunnerData(name: "You", distance: 5000, pace: "--:--", finishTime: 1500, speed: nil),
            RunnerData(name: "Bre", distance: 5000, pace: "--:--", finishTime: 1520, speed: nil),
            RunnerData(name: "John", distance: 4800, pace: "5:30", finishTime: nil, speed: nil)
        ],
        playerTime: 1500,
        distance: "3.11mi / 3.11mi",
        stats: RaceStats(
            playerName: "You",
            playerTime: 1500,
            playerPlace: 1,
            totalRunners: 3,
            raceDistanceMeters: 5000,
            useMiles: true,
        ),
        raceId: nil
    )
}


