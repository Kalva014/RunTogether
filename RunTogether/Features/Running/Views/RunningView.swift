//
//  RunningView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/27/25.
//
import SwiftUI
import SpriteKit

struct RunningView: View {
    let mode: String
    
    @StateObject private var viewModel = RunningViewModel()
    @State private var isHeartPulsing = false

    var body: some View {
        ZStack {
            SpriteView(scene: viewModel.raceScene)

            playerStatsView()
            leaderboardView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            viewModel.raceScene.size = CGSize(
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height
            )
            viewModel.raceScene.scaleMode = .fill
        }
    }

    // MARK: - Subviews

    private func playerStatsView() -> some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Pace: \(viewModel.playerPace) min/km")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Text("Distance: \(viewModel.playerDistance) m")
                            .font(.caption)
                            .foregroundColor(.white)

                        Text(viewModel.playerProgress)
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        // Live heartbeat
                        HStack {
                            Text("\(viewModel.playerHeartbeat) BPM")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Image(systemName: "heart.fill")
                                .font(.footnote)
                                .foregroundColor(.red)
                                .scaleEffect(isHeartPulsing ? 1.2 : 1.0)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                                        isHeartPulsing = true
                                    }
                                }
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                            .background(Color.black.opacity(0.2))
                    )
                    .cornerRadius(10)
                }
                .padding(.top, 40)
                .padding(.trailing, 16)
            }
            Spacer()
        }
    }

    private func leaderboardView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Leaderboard")
                .font(.headline)
                .foregroundColor(.yellow)
                .padding(.leading, 16)

            ScrollView(.vertical) {
                VStack(spacing: 4) {
                    ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, runner in
                        HStack(spacing: 4) {
                            Text("\(index + 1)")
                                .frame(width: 20, alignment: .leading)
                                .foregroundColor(.yellow)

                            Text(runner.name)
                                .frame(maxWidth: 60, alignment: .leading)
                                .lineLimit(1)

                            Text("\(Int(runner.distance))m")
                                .frame(width: 45, alignment: .trailing)

                            if index == 0 {
                                if let time = runner.finishTime {
                                    Text(viewModel.raceScene.formatTime(time))
                                        .frame(width: 50, alignment: .trailing)
                                } else {
                                    Text("\(runner.pace) min/km")
                                        .frame(width: 50, alignment: .trailing)
                                }
                            } else {
                                if let leaderTime = viewModel.leaderboard.first?.finishTime,
                                   let time = runner.finishTime {
                                    let gap = time - leaderTime
                                    Text("+\(viewModel.raceScene.formatTime(gap))")
                                        .frame(width: 50, alignment: .trailing)
                                } else {
                                    Text("\(runner.pace) min/km")
                                        .frame(width: 50, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(
                            runner.finishTime != nil
                            ? Color.green.opacity(0.5)
                            : Color.black.opacity(0.4)
                        )
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    }
                }
            }
            .frame(maxHeight: 180)
            .frame(width: 200)
        }
        .padding(.top, 50)
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    RunningView(mode: "Race")
        .environmentObject(AppEnvironment())
}
