//
//  RaceResultsView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/17/25.
//

import SwiftUI

struct RaceResultsView: View {
    let leaderboard: [RunnerData]
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
    
    init(leaderboard: [RunnerData], playerTime: TimeInterval?, distance: String, stats: RaceStats?, raceId: UUID?, onExitToHome: (() -> Void)? = nil) {
        self.leaderboard = leaderboard
        self.playerTime = playerTime
        self.distance = distance
        self.stats = stats
        self.raceId = raceId
        self.onExitToHome = onExitToHome
        
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(raceId: raceId))
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
                ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, runner in
                    HStack {
                        Text("\(index + 1)")
                            .frame(width: 24, alignment: .leading)
                            .foregroundColor(.yellow)
                        Text(runner.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let t = runner.finishTime {
                            Text(formatTime(t))
                                .monospacedDigit()
                        } else {
                            Text(runner.pace)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
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


