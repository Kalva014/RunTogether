//
//  RaceScene.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/27/25.
//
import SpriteKit
import CoreLocation

/// Race mode scene - focuses on competitive racing with finish time-based leaderboard
class RaceScene: BaseRunningScene {
    
    override init(size: CGSize) {
        super.init(size: size)
        // Any race-specific initialization can go here
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // Override to add speed property for realtime races
    override func updateLeaderboard(pace: String?) {
        var currRunners: [RunnerData] = []

        // Add player
        let playerSpeed = isTreadmillMode ? currentPlayerSpeed : (locationManager?.currentSpeed ?? 0)
        currRunners.append(RunnerData(
            name: "Ken",
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
                    finishTime: nil, // Realtime opponents don't have finish times tracked locally
                    speed: opponent.speedMps
                ))
            }
        }

        // Sort by finish time first, then by distance (race mode)
        leaderboard = currRunners.sorted {
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
}
