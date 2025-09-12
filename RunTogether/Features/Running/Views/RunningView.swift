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
    let isTreadmillMode: Bool
    let distance: String
    
    @StateObject private var viewModel: RunningViewModel
    @State private var isHeartPulsing = false
    
    init(mode: String, isTreadmillMode: Bool, distance: String) {
        self.mode = mode
        self.isTreadmillMode = isTreadmillMode
        self.distance = distance
        
        _viewModel = StateObject(wrappedValue: RunningViewModel(mode: mode, isTreadmillMode: isTreadmillMode, distance: distance))
    }


    var body: some View {
        ZStack {
            SpriteView(scene: viewModel.raceScene)

            playerStatsView()
            leaderboardView()
            
            if isTreadmillMode {
                treadmillControlsView()
            }
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
                            .font(.footnote)
                            .foregroundColor(.yellow)
                            .bold()
                        
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
            if mode == "Race" {
                Text("Leaderboard")
                    .font(.headline)
                    .foregroundColor(.yellow)
                    .padding(.leading, 16)
            }
            else if mode == "Casual" {
                Text("Runners")
                    .font(.headline)
                    .foregroundColor(.yellow)
                    .padding(.leading, 16)
            }

            ScrollView(.vertical) {
                VStack(spacing: 4) {
                    ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, runner in
                        leaderboardRow(index: index, runner: runner)
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
    
    private func leaderboardRow(index: Int, runner: RunnerData) -> some View {
        HStack(spacing: 4) {
            Text("\(index + 1)")
                .frame(width: 20, alignment: .leading)
                .foregroundColor(.yellow)

            Text(runner.name)
                .frame(maxWidth: 60, alignment: .leading)
                .lineLimit(1)

            Text("\(Int(runner.distance))m")
                .frame(width: 45, alignment: .trailing)

            Text(rowExtraText(index: index, runner: runner))
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(runner.finishTime != nil
                    ? Color.green.opacity(0.5)
                    : Color.black.opacity(0.4))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .font(.system(size: 10))
        .foregroundColor(.white)
    }

    private func rowExtraText(index: Int, runner: RunnerData) -> String {
        if index == 0 {
            if let time = runner.finishTime {
                return viewModel.raceScene.formatTime(time)
            } else {
                return "\(runner.pace) min/km"
            }
        } else {
            if let leaderTime = viewModel.leaderboard.first?.finishTime,
               let time = runner.finishTime {
                let gap = time - leaderTime
                return "+\(viewModel.raceScene.formatTime(gap))"
            } else {
                return "\(runner.pace) min/km"
            }
        }
    }


    
    private func treadmillControlsView() -> some View {
        VStack {
            // Top Spacer pushes content down
            Spacer()
            
            VStack(spacing: 20) {
                
                // Button to increase pace (decrease pace in min/km)
                VStack {
                    // `RepeatButton` for held-down functionality
                    RepeatButton(action: {
                        viewModel.updateTreadmillPace(change: -0.25)
                    }) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                    Text("Faster")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                
                // Button to decrease pace (increase pace in min/km)
                VStack {
                    // `RepeatButton` for held-down functionality
                    RepeatButton(action: {
                        viewModel.updateTreadmillPace(change: 0.25)
                    }) {
                        Image(systemName: "figure.walk.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                    Text("Slower")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
            .padding(.trailing, 20)
            
            // Bottom Spacer pushes content up
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    struct RepeatButton<Content: View>: View {
        var action: () -> Void
        var content: () -> Content
        
        @State private var timer: Timer? = nil
        
        var body: some View {
            content()
                .onLongPressGesture(minimumDuration: 0.2, pressing: { isPressing in
                    if isPressing {
                        // Initial action on press
                        action()
                        // Start the timer to repeat the action
                        self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                            action()
                        }
                    } else {
                        // Stop the timer when the press ends
                        self.timer?.invalidate()
                        self.timer = nil
                    }
                }, perform: {})
        }
    }
}

#Preview {
    RunningView(mode: "Casual", isTreadmillMode: true, distance: "5K")
        .environmentObject(AppEnvironment())
}
