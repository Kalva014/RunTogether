//
//  RunningViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/27/25.
//

import Foundation
import CoreLocation
import SpriteKit
import Combine

class RunningViewModel: ObservableObject {
    @Published var locationManager: LocationManager?
    @Published var raceScene: BaseRunningScene
    @Published var heartRate: Int = 0
    @Published var treadmillPace: Double = 0.0
    private let healthManager = HealthKitManager() // New instance of your HealthKitManager
    private var cancellables = Set<AnyCancellable>()
    var mode: String = "Race"
    var isTreadmillMode: Bool = false
    var distance: String = "5K"
    
    init(mode: String, isTreadmillMode: Bool, distance: String) {
        self.mode = mode
        self.isTreadmillMode = isTreadmillMode
        self.distance = distance
        
        if !isTreadmillMode {
            self.locationManager = LocationManager()
        } else {
            self.locationManager = nil
            self.treadmillPace = 10.0
        }
        
        // First initialize raceScene directly
        if mode == "Race" {
            self.raceScene = RaceScene(size: UIScreen.main.bounds.size)
        } else {
            self.raceScene = CasualScene(size: UIScreen.main.bounds.size)
        }
        
        // Now we can safely configure it
        self.raceScene.locationManager = self.locationManager
        self.raceScene.isTreadmillMode = self.isTreadmillMode
        self.raceScene.raceDistance = convertDistanceStringToMeters(distance)
        
        // After full initialization, we can use Combine & HealthKit
        self.raceScene.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        requestHealthKitAuthorization()
    }

      
    private func requestHealthKitAuthorization() {
        healthManager.requestAuthorization { [weak self] success in
            if success {
                print("HealthKit authorization granted.")
                self?.startHeartRateObservation()
            } else {
                print("HealthKit authorization denied.")
                // Handle the case where permission is denied
            }
        }
    }

    private func startHeartRateObservation() {
        // Corrected call to readHeartRate with a single trailing closure
        healthManager.readHeartRate { [weak self] newHeartRate in
            if let newHeartRate = newHeartRate {
                DispatchQueue.main.async {
                    self?.heartRate = Int(newHeartRate)
                }
            }
        }
    }

    func updateTreadmillPace(change: Double) {
        let newPace = max(0.0, self.treadmillPace + change)
        self.treadmillPace = newPace
        
        let speedInMps = (newPace > 0) ? 1000 / (newPace * 60) : 0
        raceScene.setPlayerSpeed(to: speedInMps)
    }
    
    // A helper function to convert the distance string
    private func convertDistanceStringToMeters(_ distanceString: String) -> Double {
        switch distanceString {
            case "5K":
                return 5000.0
            case "10K":
                return 10000.0
            case "Half Marathon(21.1K)":
                return 21100.0
            case "Full Marathon(42.2K)":
                return 42200.0
            default:
                return 5000.0 // Default to 5K if string is not recognized
        }
    }

    
    var playerPace: String {
        // Return the treadmill pace if in treadmill mode, otherwise use location manager pace
        if isTreadmillMode {
            let minutes = Int(treadmillPace)
            let seconds = Int((treadmillPace * 60).truncatingRemainder(dividingBy: 60))
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return locationManager?.paceString() ?? "--:--" // 4. Use optional chaining
        }
    }
    
    var playerDistance: Int {
        Int(raceScene.playerDistance)
    }
    
    var playerProgress: String {
        let progress = raceScene.playerDistance / raceScene.raceDistance * 100
        return String(format: "Progress: %.0f%%", progress)
    }
    
    var leaderboard: [RunnerData] {
        raceScene.leaderboard
    }
    
    var playerHeartbeat: Int {
        return self.heartRate // Return the latest heart rate from the published property
    }
}
