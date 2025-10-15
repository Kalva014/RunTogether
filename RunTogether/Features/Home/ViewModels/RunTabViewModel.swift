import Foundation
import SwiftUI

@MainActor
class RunTabViewModel: ObservableObject {
    @Published var isWaiting: Bool = false
    @Published var countdownText: String = ""
    
    private var countdownTimer: Timer?
    
    func createRace(appEnvironment: AppEnvironment, mode: String, start_time: Date, distance: Double) async -> UUID? {
        do {
            let newRace = try await appEnvironment.supabaseConnection.createRace(mode: mode, start_time: start_time, distance: distance)
            return newRace?.id
        } catch {
            print("Error creating race: \(error.localizedDescription)")
            return nil
        }
    }
    
    func joinSpecificRace(appEnvironment: AppEnvironment, raceId: String) async -> UUID? {
        do {
            guard let id = UUID(uuidString: raceId) else { return nil }
            let joined = try await appEnvironment.supabaseConnection.joinRaceWithCap(raceId: id, maxParticipants: 50)
            return joined
        } catch {
            print("Error joining race: \(error.localizedDescription)")
            return nil
        }
    }
    
    func joinRandomRace(appEnvironment: AppEnvironment, mode: String, start_time: Date, distance: Double) async -> UUID? {
        do {
            let raceId = try await appEnvironment.supabaseConnection.joinRandomRace(
                mode: mode,
                start_time: start_time,
                maxParticipants: 50,
                distance: distance
            )
            return raceId
        } catch {
            print("Error joining random race: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Wait until the race start time is within 1 minute
    @MainActor
    func waitUntilStartTime(startTime: Date) async {
        self.isWaiting = true

        while true {
            let now = Date()
            let diff = startTime.timeIntervalSince(now)

            if diff <= 60 {
                self.isWaiting = false
                break
            } else {
                let minutes = Int(diff / 60)
                let seconds = Int(diff.truncatingRemainder(dividingBy: 60))
                self.countdownText = String(format: "Starts in %02dm %02ds", minutes, seconds)
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }

    
    func waitForRaceToStart(appEnvironment: AppEnvironment, raceId: String) async {
        do {
            guard let uuid = UUID(uuidString: raceId) else { return }
            let race = try await appEnvironment.supabaseConnection.getRaceDetails(raceId: uuid)
            await waitUntilStartTime(startTime: race.start_time)
        } catch {
            print("Error waiting for race start: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func cancelRace(appEnvironment: AppEnvironment, raceId: UUID) async {
        do {
            try await appEnvironment.supabaseConnection.cancelRace(raceId: raceId)
            print("✅ Race \(raceId) cancelled successfully")
        } catch {
            print("❌ Failed to cancel race: \(error)")
        }
    }

    @MainActor
    func leaveRace(appEnvironment: AppEnvironment, raceId: UUID) async {
        do {
            try await appEnvironment.supabaseConnection.leaveRace(raceId: raceId)
            print("👋 Left race \(raceId)")
        } catch {
            print("❌ Failed to leave race: \(error)")
        }
    }
}
