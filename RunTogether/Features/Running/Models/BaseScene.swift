//
//  BaseScene.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/12/25.
//

import Foundation
import SpriteKit
import CoreLocation
import Combine

/// A shared base class for RaceScene and CasualScene.
/// Holds common state and behavior for all running scenes.
class BaseRunningScene: SKScene, ObservableObject {
    
    // MARK: - Published Properties
    @Published var leaderboard: [RunnerData] = []
    @Published var playerDistance: Double = 0.0
    
    // MARK: - Shared State
    var locationManager: LocationManager?
    var isTreadmillMode: Bool = false
    var raceDistance: Double = 5000.0 // Default 5K
    private var playerSpeed: Double = 0.0
    
    // MARK: - Combine
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Lifecycle
    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .white
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // MARK: - Player Speed
    /// Updates the player’s speed (in meters/second).
    func setPlayerSpeed(to speed: Double) {
        playerSpeed = speed
    }
    
    /// Call this during updates (e.g., treadmill mode simulation or GPS updates)
    func updatePlayerDistance(deltaTime: TimeInterval) {
        guard playerSpeed > 0 else { return }
        playerDistance += playerSpeed * deltaTime
    }
    
    // MARK: - Leaderboard
    func updateLeaderboard(with runners: [RunnerData]) {
        leaderboard = runners.sorted { $0.distance > $1.distance }
    }
    
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
