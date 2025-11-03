//
//  CasualScene.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/27/25.
//
import SpriteKit
import CoreLocation

/// Casual mode scene - focuses on pace-based competition rather than racing to finish
class CasualScene: BaseRunningScene {
    
    override init(size: CGSize) {
        super.init(size: size)
        // Any casual-specific initialization can go here
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // Override leaderboard to sort by pace instead of finish time/distance
    override func updateLeaderboard(pace: String?) {
        var currRunners: [RunnerData] = []

        // Add player
        let playerSpeed = isTreadmillMode ? currentPlayerSpeed : (locationManager?.currentSpeed ?? 0)
        currRunners.append(RunnerData(
            name: "You",
            distance: playerDistance,
            pace: pace ?? "--:--",
            finishTime: finishTimes[-1],
            speed: playerSpeed
        ))

        // Add AI opponents (for non-realtime mode)
        if !isRealtimeEnabled {
            for i in 0..<otherRunners.count {
                currRunners.append(RunnerData(
                    name: otherRunnersNames[i],
                    distance: otherRunnersCurrentDistances[i],
                    pace: calculatePace(from: otherRunnersSpeeds[i], useMiles: useMiles),
                    finishTime: finishTimes[i],
                    speed: Double(otherRunnersSpeeds[i])
                ))
            }
        } else {
            // Add realtime opponents
            for (userId, opponent) in realtimeOpponents where !opponent.isStale {
                currRunners.append(RunnerData(
                    name: opponent.username,
                    distance: CGFloat(opponent.distance),
                    pace: opponent.paceString(),
                    finishTime: nil,
                    speed: opponent.speedMps
                ))
            }
        }

        // Sort by pace (faster pace = lower time = better ranking)
        leaderboard = currRunners.sorted { runner1, runner2 in
            let pace1Components = runner1.pace.split(separator: ":").compactMap { Int($0) }
            let pace2Components = runner2.pace.split(separator: ":").compactMap { Int($0) }

            guard pace1Components.count == 2, pace2Components.count == 2 else {
                return runner1.pace != "--:--" && runner2.pace == "--:--"
            }

            let seconds1 = pace1Components[0] * 60 + pace1Components[1]
            let seconds2 = pace2Components[0] * 60 + pace2Components[1]
            return seconds1 < seconds2
        }
    }
}
