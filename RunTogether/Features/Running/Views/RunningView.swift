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
    var useMiles: Bool
    let raceId: UUID?
    
    @EnvironmentObject var appEnvironment: AppEnvironment
    
    @StateObject private var viewModel: RunningViewModel
    @StateObject private var chatViewModel: ChatViewModel
    @State private var isHeartPulsing = false
    @State private var navigateToResults = false
    @State private var showMenu = false
    @State private var showLeaveConfirmation = false
    @State private var showChat = false
    @Environment(\.dismiss) private var dismiss
    
    init(mode: String, isTreadmillMode: Bool, distance: String, useMiles: Bool, raceId: UUID? = nil) {
        self.mode = mode
        self.isTreadmillMode = isTreadmillMode
        self.distance = distance
        self.useMiles = useMiles
        self.raceId = raceId
                
        _viewModel = StateObject(wrappedValue: RunningViewModel(mode: mode, isTreadmillMode: isTreadmillMode, distance: distance, useMiles: useMiles, raceId: raceId))
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(raceId: raceId))
    }


    var body: some View {
        ZStack {
            SpriteView(scene: viewModel.raceScene)

            playerStatsView()
            leaderboardView()
            
            if isTreadmillMode {
                treadmillControlsView()
            }

            // Results button overlay when race is over
            if viewModel.raceScene.isRaceOver {
                VStack {
                    Spacer()
                    Button(action: { navigateToResults = true }) {
                        Text("View Results")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(Color.yellow)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    }
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: viewModel.raceScene.isRaceOver)
            }
            
            // Menu overlay
            if showMenu {
                menuOverlay()
            }
            
            // Chat overlay
            if showChat {
                ZStack {
                    // Semi-transparent background that dismisses chat on tap
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showChat = false
                            }
                        }
                    
                    ChatView(viewModel: chatViewModel, isPresented: $showChat)
                        .transition(.move(edge: .bottom))
                        .allowsHitTesting(true)
                }
                .zIndex(100)
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
            
            viewModel.setAppEnvironment(appEnvironment: appEnvironment)
            
            // Start realtime updates if we have supabaseconnection and raceid
            Task {
                if appEnvironment.supabaseConnection != nil {
                    await viewModel.startRealtime(appEnvironment: appEnvironment)
                } else {
                    // fallback: no supabase connection available
                    print("No SupabaseConnection available in environment.")
                }
            }
        }
        .onDisappear {
            Task {
                await viewModel.stopRealtime(appEnvironment: appEnvironment)
            }
        }
        .background(
            NavigationLink(isActive: $navigateToResults) {
                RaceResultsView(
                    leaderboard: viewModel.leaderboard,
                    playerTime: viewModel.raceScene.finishTimes[-1],
                    distance: viewModel.playerProgressDetail,
                    stats: RaceStats(
                        playerName: "You",
                        playerTime: viewModel.raceScene.finishTimes[-1],
                        playerPlace: (viewModel.leaderboard.firstIndex(where: { $0.name == "You" }) ?? 0) + 1,
                        totalRunners: viewModel.leaderboard.count,
                        raceDistanceMeters: Double(viewModel.raceScene.raceDistance),
                        useMiles: useMiles,
                    ),
                    raceId: raceId,
                    onExitToHome: { dismiss() }
                )
            } label: { EmptyView() }
                .hidden()
        )
        .alert("Leave Race?", isPresented: $showLeaveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                Task {
                    if let raceId = raceId {
                        await viewModel.stopRealtime(appEnvironment: appEnvironment)
                        // Optionally call leaveRace on the backend if needed
                        try await appEnvironment.supabaseConnection.leaveRace(raceId: raceId)
                    }
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to leave this race? Your progress will be lost.")
        }
    }

    // MARK: - Subviews
    private func playerStatsView() -> some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 12) {
                        // Chat button (only show if raceId exists)
                        if raceId != nil {
                            Button(action: {
                                showChat.toggle()
                            }) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Settings button
                        Button(action: {
                            showMenu.toggle()
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                    }

                    VStack(alignment: .trailing, spacing: 8) {
                        // Pace
                        Text("Pace: \(viewModel.playerPace) \(useMiles ? "min/mi" : "min/km")")
                            .font(.footnote)
                            .foregroundColor(.yellow)
                            .bold()

                        // Distance (formatted string)
                        Text("Distance: \(viewModel.playerDistanceString)")
                            .font(.caption)
                            .foregroundColor(.white)

                        // Progress % + covered/total
                        Text(viewModel.playerProgressPercent)
                            .font(.caption)
                            .foregroundColor(.white)

                        Text(viewModel.playerProgressDetail)
                            .font(.caption2)
                            .foregroundColor(.gray)

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

            Text(viewModel.formattedDistance(runner.distance))
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
        if useMiles == false {
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
        else {
            if index == 0 {
                if let time = runner.finishTime {
                    return viewModel.raceScene.formatTime(time)
                } else {
                    return "\(runner.pace) min/mi"
                }
            } else {
                if let leaderTime = viewModel.leaderboard.first?.finishTime,
                   let time = runner.finishTime {
                    let gap = time - leaderTime
                    return "+\(viewModel.raceScene.formatTime(gap))"
                } else {
                    return "\(runner.pace) min/mi"
                }
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
    
    // MARK: - Menu Overlay
    private func menuOverlay() -> some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    showMenu = false
                }
            
            // Menu content
            VStack(spacing: 20) {
                Text("Race Menu")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                // Copy Race ID button
                if let raceId = raceId {
                    Button(action: {
                        UIPasteboard.general.string = raceId.uuidString
                        showMenu = false
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .font(.title3)
                            Text("Copy Race ID")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(10)
                    }
                    
                    Text(raceId.uuidString)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                // Leave Race button
                Button(action: {
                    showMenu = false
                    showLeaveConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title3)
                        Text("Leave Race")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
                }
                
                // Close button
                Button(action: {
                    showMenu = false
                }) {
                    Text("Close")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.6))
                        .cornerRadius(10)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.9))
                    .shadow(radius: 20)
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: showMenu)
    }
}

#Preview {
    let supabaseConnection = SupabaseConnection()

    RunningView(mode: "Casual", isTreadmillMode: true, distance: "1 Mile", useMiles: true)
        .environmentObject(AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"), supabaseConnection: supabaseConnection))
}
