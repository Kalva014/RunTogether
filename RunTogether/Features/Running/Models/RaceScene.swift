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
    
    // RaceScene uses the default leaderboard implementation from BaseRunningScene
    // which sorts by finish time first, then by distance
    
    override init(size: CGSize) {
        super.init(size: size)
        // Any race-specific initialization can go here
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // Race scene uses the default leaderboard sorting (by finish time, then distance)
    // No override needed since BaseRunningScene provides the correct behavior
}
