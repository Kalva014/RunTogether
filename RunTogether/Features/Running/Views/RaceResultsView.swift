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
    
    // A callback to handle the navigation action
    var onExitToHome: (() -> Void)? = nil
    
    // An Environment variable to dismiss the view
    @Environment(\.dismiss) private var dismiss
    
    // Programmatic navigation to Home
    @State private var navigateHome: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: { navigateHome = true }) {
                Text("Home")
            }.buttonStyle(.borderedProminent)
            
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
            RunnerData(name: "Ken", distance: 5000, pace: "--:--", finishTime: 1500, speed: nil),
            RunnerData(name: "Bre", distance: 5000, pace: "--:--", finishTime: 1520, speed: nil),
            RunnerData(name: "John", distance: 4800, pace: "5:30", finishTime: nil, speed: nil)
        ],
        playerTime: 1500,
        distance: "3.11mi / 3.11mi",
        stats: RaceStats(
            playerName: "Ken",
            playerTime: 1500,
            playerPlace: 1,
            totalRunners: 3,
            raceDistanceMeters: 5000,
            useMiles: true
        )
    )
}


