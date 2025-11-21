//
//  RunningView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/27/25.
//

// ==========================================
// MARK: - RunningView.swift - COMPLETE
// ==========================================
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
    @State private var showLeaderboard = false
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
            // Game scene
            SpriteView(scene: viewModel.raceScene)
                .ignoresSafeArea()
                .allowsHitTesting(!viewModel.raceScene.isRaceOver) // Disable touch when race is over
                .opacity(viewModel.raceScene.isRaceOver ? 0.8 : 1.0) // Dim scene when race is over

            // Overlay UI
            VStack {
                // Top stats
                topStatsBar
                
                Spacer()
                
                // Bottom controls
                if !viewModel.raceScene.isRaceOver {
                    bottomControls
                }
            }
            
            // Treadmill controls sidebar (right side)
            if isTreadmillMode && !viewModel.raceScene.isRaceOver {
                treadmillSidebar
            }
            
            // Leaderboard sidebar
            if showLeaderboard {
                leaderboardSidebar
            }

            // Results button when race is over
            if viewModel.raceScene.isRaceOver {
                VStack {
                    Spacer()
                    
                    Button(action: { 
                        print("🎯 Results button tapped - navigating to results")
                        print("🎯 Current navigateToResults value: \(navigateToResults)")
                        print("🎯 Race over status: \(viewModel.raceScene.isRaceOver)")
                        navigateToResults = true 
                        print("🎯 Set navigateToResults to: \(navigateToResults)")
                    }) {
                        HStack {
                            Image(systemName: "flag.checkered")
                            Text("View Results")
                                .fontWeight(.bold)
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .cornerRadius(16)
                        .shadow(color: Color.orange.opacity(0.5), radius: 10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
                .zIndex(1000) // Ensure button is on top
                .allowsHitTesting(true) // Explicitly allow hit testing
            }
            
            // Menu overlay
            if showMenu {
                menuOverlay
            }
            
            // Chat overlay
            if showChat {
                chatOverlay
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.raceScene.size = CGSize(
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height
            )
            viewModel.raceScene.scaleMode = .fill
            
            viewModel.setAppEnvironment(appEnvironment: appEnvironment)
            
            Task {
                if appEnvironment.supabaseConnection != nil {
                    await viewModel.startRealtime(appEnvironment: appEnvironment)
                    
                    if raceId != nil {
                        await chatViewModel.startChat(appEnvironment: appEnvironment)
                    }
                }
            }
        }
        .onChange(of: viewModel.raceScene.isRaceOver) { isRaceOver in
            guard isRaceOver else { return }
            Task {
                await viewModel.stopRealtime(appEnvironment: appEnvironment)
                await chatViewModel.stopChat()
            }
        }
        .onDisappear {
            Task {
                await viewModel.stopRealtime(appEnvironment: appEnvironment)
                await chatViewModel.stopChat()
                
                // Only clean up if we're not navigating to results
                if !navigateToResults {
                    if let raceId = raceId {
                        // Only leave race if we haven't finished (to preserve results)
                        if !viewModel.raceScene.isRaceOver {
                            try? await appEnvironment.supabaseConnection.leaveRace(raceId: raceId)
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $navigateToResults) {
            NavigationStack {
                RaceResultsView(
                    leaderboard: viewModel.leaderboard,
                    playerTime: viewModel.raceScene.finishTimes[-1],
                    distance: viewModel.playerProgressDetail,
                    stats: RaceStats(
                        playerName: "You",
                        playerTime: viewModel.raceScene.finishTimes[-1],
                        playerPlace: 1, // Will be recalculated in RaceResultsView based on final leaderboard
                        totalRunners: viewModel.leaderboard.count,
                        raceDistanceMeters: Double(viewModel.raceScene.raceDistance),
                        useMiles: useMiles
                    ),
                    raceId: raceId
                )
                .onAppear {
                    print("🏁 Navigating to results with player finish time: \(viewModel.raceScene.finishTimes[-1] ?? -1)")
                    print("🏁 Current leaderboard:")
                    for (index, runner) in viewModel.leaderboard.enumerated() {
                        let status = runner.finishTime != nil ? "FINISHED(\(runner.finishTime!))" : "ACTIVE"
                        print("  \(index + 1). \(runner.name) - \(status) - distance: \(runner.distance)")
                    }
                }
            }
        }
        .alert("Leave Race?", isPresented: $showLeaveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                Task {
                    print("🚪 User initiated race leave")
                    
                    do {
                        if let raceId = raceId {
                            // Stop realtime first
                            await viewModel.stopRealtime(appEnvironment: appEnvironment)
                            await chatViewModel.stopChat()
                            
                            // Mark as disconnected if race is still active
                            if !viewModel.raceScene.isRaceOver {
                                try await appEnvironment.supabaseConnection.markParticipantDisconnected(
                                    raceId: raceId, 
                                    userId: appEnvironment.supabaseConnection.currentUserId ?? UUID()
                                )
                                print("✅ Marked as disconnected")
                            }
                            
                            // Leave the race
                            try await appEnvironment.supabaseConnection.leaveRace(raceId: raceId)
                            print("✅ Successfully left race")
                        }
                        
                        // Always dismiss the view, even if there were errors
                        print("🔄 Attempting to dismiss RunningView")
                        await MainActor.run {
                            dismiss()
                        }
                        
                    } catch {
                        print("❌ Error during race leave: \(error)")
                        // Still dismiss even if there was an error
                        print("🔄 Dismissing despite error")
                        await MainActor.run {
                            dismiss()
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to leave this race? Your progress will be lost.")
        }
    }

    // MARK: - Top Stats Bar
    private var topStatsBar: some View {
        HStack {
            // Menu button
            Button(action: { showMenu.toggle() }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 8) {
                // Total Race Time
                HStack(spacing: 6) {
                    Image(systemName: "stopwatch")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(viewModel.totalRaceTime)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                
                // Pace
                HStack(spacing: 6) {
                    Text(viewModel.playerPace)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(useMiles ? "min/mi" : "min/km")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                
                // Distance & Progress
                VStack(alignment: .trailing, spacing: 4) {
                    Text(viewModel.playerDistanceString)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(viewModel.playerProgressDetail)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                
                // Heart rate
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .scaleEffect(isHeartPulsing ? 1.2 : 1.0)
                    
                    Text("\(viewModel.playerHeartbeat)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("BPM")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        isHeartPulsing = true
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        // Main action buttons (centered)
        HStack {
            Spacer()
            
            // Leaderboard toggle
            Button(action: { showLeaderboard.toggle() }) {
                HStack {
                    Image(systemName: "list.number")
                    Text("Board")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(showLeaderboard ? Color.orange : Color.black.opacity(0.6))
                .cornerRadius(12)
            }
            
            // Chat button
            if raceId != nil {
                Button(action: { showChat.toggle() }) {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("Chat")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(showChat ? Color.orange : Color.black.opacity(0.6))
                    .cornerRadius(12)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    // MARK: - Treadmill Sidebar
    private var treadmillSidebar: some View {
        HStack {
            Spacer()
            
            VStack(spacing: 20) {
                // Increase pace button (top)
                RepeatButton(action: {
                    viewModel.updateTreadmillPace(change: -0.25)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 55))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                .frame(width: 70, height: 70)
                
                // Pace display
                VStack(spacing: 6) {
                    Text(String(format: "%.2f", viewModel.treadmillPace))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("pace")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(width: 80, height: 60)
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
                
                // Decrease pace button (bottom)
                RepeatButton(action: {
                    viewModel.updateTreadmillPace(change: 0.25)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 55))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                .frame(width: 70, height: 70)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(Color.black.opacity(0.6))
            .cornerRadius(25)
            .padding(.trailing, 20)
        }
    }
    
    struct RepeatButton<Content: View>: View {
        var action: () -> Void
        var content: () -> Content
        
        @State private var timer: Timer? = nil
        
        var body: some View {
            content()
                .onLongPressGesture(minimumDuration: 0.2, pressing: { isPressing in
                    if isPressing {
                        action()
                        self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                            action()
                        }
                    } else {
                        self.timer?.invalidate()
                        self.timer = nil
                    }
                }, perform: {})
        }
    }
    
    // MARK: - Leaderboard Sidebar
    private var leaderboardSidebar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(mode == "Race" ? "Leaderboard" : "Runners")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { showLeaderboard = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, runner in
                            leaderboardRow(index: index, runner: runner)
                        }
                    }
                }
            }
            .padding(16)
            .frame(width: 280)
            .background(Color.black.opacity(0.9))
            .cornerRadius(20, corners: [.topRight, .bottomRight])
            
            Spacer()
        }
        .transition(.move(edge: .leading))
        .animation(.spring(response: 0.3), value: showLeaderboard)
    }
    
    private func leaderboardRow(index: Int, runner: RunnerData) -> some View {
        HStack(spacing: 8) {
            // Rank
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(runner.name == "You" ? .orange : .white)
                .frame(width: 24)
            
            // Name
            Text(runner.name)
                .font(.subheadline)
                .foregroundColor(runner.name == "You" ? .orange : .white)
                .lineLimit(1)
            
            Spacer()
            
            // Pace and Distance/Time
            VStack(alignment: .trailing, spacing: 2) {
                // Pace
                Text(runner.pace)
                    .font(.caption2)
                    .foregroundColor(.orange)
                
                // Distance or time
                if let time = runner.finishTime {
                    Text(viewModel.raceScene.formatTime(time))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                } else {
                    Text(viewModel.formattedDistance(runner.distance))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            runner.name == "You"
                ? Color.orange.opacity(0.2)
                : runner.finishTime != nil
                    ? Color.green.opacity(0.1)
                    : Color.white.opacity(0.05)
        )
        .cornerRadius(8)
    }
    
    // MARK: - Results Button
    private var resultsButton: some View {
        VStack {
            Spacer()
            
            Button(action: { 
                print("🎯 Results button tapped - navigating to results")
                navigateToResults = true 
            }) {
                HStack {
                    Image(systemName: "flag.checkered")
                    Text("View Results")
                        .fontWeight(.bold)
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange)
                .cornerRadius(16)
                .shadow(color: Color.orange.opacity(0.5), radius: 10)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom))
        .animation(.spring(response: 0.4), value: viewModel.raceScene.isRaceOver)
    }
    
    // MARK: - Menu Overlay
    private var menuOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { showMenu = false }
            
            VStack(spacing: 20) {
                Text("Race Menu")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                if let raceId = raceId {
                    VStack(spacing: 12) {
                        Text("Race ID")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text(raceId.uuidString)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Button(action: {
                                UIPasteboard.general.string = raceId.uuidString
                                showMenu = false
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                Button(action: {
                    showMenu = false
                    showLeaveConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Leave Race")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
                }
                
                Button(action: { showMenu = false }) {
                    Text("Close")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            .padding(30)
            .background(Color(white: 0.1))
            .cornerRadius(20)
            .padding(.horizontal, 40)
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
}

#Preview {
    let supabaseConnection = SupabaseConnection()

    RunningView(mode: "Race", isTreadmillMode: false, distance: "5K", useMiles: false)
        .environmentObject(AppEnvironment(
            appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"),
            supabaseConnection: supabaseConnection
        ))
}
