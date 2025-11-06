//
//  RaceResultsViewModel.swift
//  RunTogether
//
//  Created for realtime leaderboard updates in RaceResultsView
//

import Foundation
import Combine

@MainActor
class RaceResultsViewModel: ObservableObject {
    @Published var leaderboard: [RunnerData] = []
    @Published var isUpdating: Bool = false
    
    private let initialLeaderboard: [RunnerData]
    private var realtimeOpponents: [UUID: RealtimeOpponentData] = [:]
    private var profileCache: [UUID: Profile] = [:] // Cache profiles for quick lookup
    private var raceId: UUID?
    private var appEnvironment: AppEnvironment?
    private var useMiles: Bool
    
    init(initialLeaderboard: [RunnerData], raceId: UUID?, useMiles: Bool) {
        self.initialLeaderboard = initialLeaderboard
        self.leaderboard = initialLeaderboard
        self.raceId = raceId
        self.useMiles = useMiles
    }
    
    func startRealtimeUpdates(appEnvironment: AppEnvironment) async {
        guard let raceId = self.raceId else {
            print("❌ No raceId provided for realtime updates")
            return
        }
        
        self.appEnvironment = appEnvironment
        
        print("📊 Starting realtime leaderboard updates for race: \(raceId)")
        
        // Initial build from database
        await checkFinishTimes()
        
        // Subscribe to race broadcasts
        await appEnvironment.supabaseConnection.subscribeToRaceBroadcasts(raceId: raceId)
        
        // Start processing incoming messages
        Task { @MainActor in
            await processRealtimeMessages(appEnvironment: appEnvironment)
        }
        
        // Also poll for finish times periodically
        startPollingFinishTimes()
    }
    
    func stopRealtimeUpdates() async {
        guard let appEnvironment = appEnvironment else { return }
        
        await appEnvironment.supabaseConnection.unsubscribeFromRaceBroadcasts()
        realtimeOpponents.removeAll()
        print("🛑 Stopped realtime leaderboard updates")
    }
    
    private func processRealtimeMessages(appEnvironment: AppEnvironment) async {
        guard let channel = appEnvironment.supabaseConnection.currentChannel else {
            print("❌ No channel available for processing messages")
            return
        }
        
        let stream = await channel.broadcastStream(event: "update")
        print("✅ Started listening to leaderboard update stream")
        
        for await message in stream {
            // Extract payload from the message
            guard let payload = message["payload"]?.objectValue else {
                continue
            }
            
            guard let userIdString = payload["user_id"]?.stringValue,
                  let userId = UUID(uuidString: userIdString) else {
                continue
            }
            
            let distance = payload["distance"]?.doubleValue ?? 0
            let pace = payload["pace"]?.doubleValue ?? 0
            let speedMps = pace > 0 ? 1000 / (pace * 60) : 0
            
            // Skip our own messages
            if userId == appEnvironment.supabaseConnection.currentUserId {
                continue
            }
            
            // Update or create opponent data
            if realtimeOpponents[userId] != nil {
                realtimeOpponents[userId]?.distance = distance
                realtimeOpponents[userId]?.paceMinutes = pace
                realtimeOpponents[userId]?.speedMps = speedMps
                realtimeOpponents[userId]?.lastUpdateTime = Date()
                await updateLeaderboard()
            } else {
                // Fetch profile for new opponent
                Task { @MainActor in
                    if let profile = try? await appEnvironment.supabaseConnection.getProfileById(userId: userId) {
                        profileCache[userId] = profile
                        realtimeOpponents[userId] = RealtimeOpponentData(
                            userId: userId,
                            username: profile.username,
                            distance: distance,
                            paceMinutes: pace,
                            speedMps: speedMps,
                            lastUpdateTime: Date()
                        )
                        await updateLeaderboard()
                    }
                }
            }
        }
    }
    
    private func updateLeaderboard() async {
        isUpdating = true
        defer { isUpdating = false }
        
        // Use current leaderboard state (which includes finished runners from database)
        let currentFinishedRunners = leaderboard.filter { $0.finishTime != nil }
        var activeRunners: [RunnerData] = []
        
        // Track which runners we've seen from realtime
        var seenRealtimeRunnerNames = Set<String>()
        
        // Add active runners from realtime data
        for (userId, opponent) in realtimeOpponents where !opponent.isStale {
            // Check if this runner already finished
            let existingFinishedRunner = currentFinishedRunners.first { runner in
                runner.name == opponent.username
            }
            
            // Only add active runners who haven't finished
            if existingFinishedRunner == nil {
                // Format pace string
                let paceString = formatPace(paceMinutes: opponent.paceMinutes)
                
                // Get profile picture from cache if available
                let profilePictureUrl = profileCache[opponent.userId]?.profile_picture_url
                
                activeRunners.append(RunnerData(
                    name: opponent.username,
                    distance: CGFloat(opponent.distance),
                    pace: paceString,
                    finishTime: nil,
                    speed: opponent.speedMps,
                    profilePictureUrl: profilePictureUrl
                ))
                seenRealtimeRunnerNames.insert(opponent.username)
            }
        }
        
        // Add any runners from current leaderboard who haven't finished and aren't in realtime data
        // (in case they're still running but haven't sent updates yet)
        for runner in leaderboard {
            if runner.finishTime == nil && !seenRealtimeRunnerNames.contains(runner.name) {
                activeRunners.append(runner)
            }
        }
        
        // Combine: finished runners first, then active runners
        let updatedLeaderboard = currentFinishedRunners + activeRunners
        
        // Sort: finished runners first (by time), then active runners (by distance)
        leaderboard = updatedLeaderboard.sorted {
            if let t1 = $0.finishTime, let t2 = $1.finishTime {
                return t1 < t2
            } else if $0.finishTime != nil {
                return true
            } else if $1.finishTime != nil {
                return false
            } else {
                return $0.distance > $1.distance
            }
        }
    }
    
    private func formatPace(paceMinutes: Double) -> String {
        guard paceMinutes > 0 else { return "--:--" }
        
        let minutes = Int(paceMinutes)
        let seconds = Int((paceMinutes * 60).truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var finishTimePollingTask: Task<Void, Never>?
    
    private func startPollingFinishTimes() {
        finishTimePollingTask?.cancel()
        
        finishTimePollingTask = Task {
            while !Task.isCancelled {
                await checkFinishTimes()
                try? await Task.sleep(nanoseconds: 3_000_000_000) // Poll every 3 seconds
            }
        }
    }
    
    private func checkFinishTimes() async {
        guard let raceId = raceId,
              let appEnvironment = appEnvironment else { return }
        
        do {
            // Fetch all race participants with their finish times
            let participants: [RaceParticipants] = try await appEnvironment.supabaseConnection.client
                .from("Race_Participants")
                .select()
                .eq("race_id", value: raceId.uuidString)
                .execute()
                .value ?? []
            
            // Remove finished runners from realtime tracking
            for participant in participants {
                if participant.finish_time != nil {
                    realtimeOpponents.removeValue(forKey: participant.user_id)
                }
            }
            
            // Build complete leaderboard with all participants
            await buildCompleteLeaderboard(participants: participants, appEnvironment: appEnvironment)
            
        } catch {
            print("Error checking finish times: \(error)")
        }
    }
    
    private func buildCompleteLeaderboard(participants: [RaceParticipants], appEnvironment: AppEnvironment) async {
        var completeLeaderboard: [RunnerData] = []
        
        // Get race start time
        var raceStartTime: Date?
        if let raceId = raceId {
            do {
                let race = try await appEnvironment.supabaseConnection.getRaceDetails(raceId: raceId)
                raceStartTime = race.start_time
                print("📅 Race start time: \(race.start_time)")
            } catch {
                print("❌ Error fetching race start time: \(error)")
            }
        }
        
        // Create a map of initial leaderboard data (by name) to preserve finish times and paces
        var initialDataMap: [String: RunnerData] = [:]
        for runner in initialLeaderboard {
            initialDataMap[runner.name] = runner
        }
        
        // Get profiles for all participants
        let userIds = participants.map { $0.user_id }
        var profiles: [UUID: Profile] = [:]
        
        for userId in userIds {
            // Check cache first
            if let cachedProfile = profileCache[userId] {
                profiles[userId] = cachedProfile
            } else if let profile = try? await appEnvironment.supabaseConnection.getProfileById(userId: userId) {
                profiles[userId] = profile
                profileCache[userId] = profile // Cache for future use
            }
        }
        
        // Build leaderboard from participants
        for participant in participants {
            let username = profiles[participant.user_id]?.username ?? "Unknown"
            
            // First, try to get finish time from initial leaderboard (might be more accurate)
            var finishTime: TimeInterval? = nil
            if let initialRunner = initialDataMap[username] {
                finishTime = initialRunner.finishTime
            }
            
            // If not in initial leaderboard, calculate from database
            if finishTime == nil, let finishTimeString = participant.finish_time,
               let startTime = raceStartTime {
                // Try parsing with ISO8601DateFormatter
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                if let finishTimeDate = formatter.date(from: finishTimeString) {
                    // Calculate elapsed time in seconds
                    finishTime = finishTimeDate.timeIntervalSince(startTime)
                    print("✅ Calculated finish time for \(username): \(finishTime ?? 0) seconds")
                } else {
                    // Try without fractional seconds
                    let simpleFormatter = ISO8601DateFormatter()
                    if let finishTimeDate = simpleFormatter.date(from: finishTimeString) {
                        finishTime = finishTimeDate.timeIntervalSince(startTime)
                        print("✅ Calculated finish time (simple) for \(username): \(finishTime ?? 0) seconds")
                    } else {
                        print("⚠️ Could not parse finish_time '\(finishTimeString)' for \(username)")
                    }
                }
            }
            
            // Get current distance and pace from realtime data or participant data
            let distance: CGFloat
            let pace: String
            
            if let opponent = realtimeOpponents[participant.user_id] {
                // Still running - use realtime data
                distance = CGFloat(opponent.distance)
                pace = formatPace(paceMinutes: opponent.paceMinutes)
                print("📊 \(username): Using realtime data - pace: \(pace)")
            } else if let initialRunner = initialDataMap[username], !initialRunner.pace.isEmpty && initialRunner.pace != "--:--" {
                // Use initial leaderboard pace if available
                distance = initialRunner.distance
                pace = initialRunner.pace
                print("📊 \(username): Using initial leaderboard data - pace: \(pace)")
            } else if participant.finish_time != nil {
                // Finished - use participant data
                distance = CGFloat(participant.distance_covered)
                if let avgPace = participant.average_pace, avgPace > 0 {
                    pace = formatPace(paceMinutes: avgPace)
                    print("🏁 \(username): Finished - average_pace: \(avgPace), formatted: \(pace)")
                } else {
                    // Calculate pace from distance and finish time if available
                    if let ft = finishTime, ft > 0 {
                        // Calculate average pace in min/km or min/mi
                        let distanceKm = participant.distance_covered / 1000.0
                        let paceMinutes = ft / 60.0 / distanceKm
                        pace = formatPace(paceMinutes: paceMinutes)
                        print("🏁 \(username): Calculated pace from finish time: \(pace)")
                    } else {
                        pace = "--:--"
                        print("⚠️ \(username): Finished but no average_pace and can't calculate")
                    }
                }
            } else {
                // No recent update - use last known distance
                distance = CGFloat(participant.distance_covered)
                pace = "--:--"
                print("📊 \(username): No realtime data or finish time - pace: --:--")
            }
            
            let profile = profiles[participant.user_id]
            completeLeaderboard.append(RunnerData(
                name: username,
                distance: distance,
                pace: pace,
                finishTime: finishTime,
                speed: nil,
                profilePictureUrl: profile?.profile_picture_url
            ))
        }
        
        // Sort: finished runners first (by finish time), then active runners (by distance)
        leaderboard = completeLeaderboard.sorted {
            if let t1 = $0.finishTime, let t2 = $1.finishTime {
                return t1 < t2
            } else if $0.finishTime != nil {
                return true
            } else if $1.finishTime != nil {
                return false
            } else {
                return $0.distance > $1.distance
            }
        }
    }
    
    deinit {
        finishTimePollingTask?.cancel()
    }
}

// Helper struct matching BaseScene's RealtimeOpponentData
private struct RealtimeOpponentData {
    var userId: UUID
    var username: String
    var distance: Double
    var paceMinutes: Double
    var speedMps: Double
    var lastUpdateTime: Date
    
    var isStale: Bool {
        Date().timeIntervalSince(lastUpdateTime) > 10 // 10 seconds stale threshold
    }
}

