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

@MainActor
class RunningViewModel: ObservableObject {
    @Published var locationManager: LocationManager?
    @Published var raceScene: BaseRunningScene
    @Published var heartRate: Int = 0
    @Published var treadmillPace: Double = 0.0
    @Published var useMiles: Bool {
        didSet {
            raceScene.raceDistance = convertDistanceToMeters(distance)
        }
    }
    private let healthManager = HealthKitManager() // New instance of your HealthKitManager
    private var cancellables = Set<AnyCancellable>()
    var mode: String = "Race"
    var isTreadmillMode: Bool = false
    var distance: String = "5K"
    
    init(mode: String, isTreadmillMode: Bool, distance: String, useMiles: Bool) {
        self.mode = mode
        self.isTreadmillMode = isTreadmillMode
        self.distance = distance
        self.useMiles = useMiles
        
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
        self.raceScene.useMiles = useMiles
        self.raceScene.locationManager = self.locationManager
        self.raceScene.isTreadmillMode = self.isTreadmillMode
        
        let meters = convertDistanceToMeters(distance)
        self.raceScene.raceDistance = meters
        
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

        let metersPerUnit = useMiles ? 1609.34 : 1000.0
        let speedInMps = (newPace > 0) ? metersPerUnit / (newPace * 60) : 0
        raceScene.setPlayerSpeed(to: speedInMps)
    }
    
    // A helper function to convert the distance string
    private func convertDistanceToMeters(_ distance: String) -> Double {
        if useMiles {
            switch distance {
            case "1 Mile": return 1609.34
            case "3.1 Miles": return 4989.0
            case "6.2 Miles": return 9979.0
            case "13.1 Miles": return 21092.0
            case "26.2 Miles": return 42195.0
            default: return 1609.34
            }
        } else {
            switch distance {
            case "5K": return 5000.0
            case "10K": return 10000.0
            case "Half Marathon (21.1K)": return 21100.0
            case "Full Marathon (42.2K)": return 42200.0
            default: return 5000.0
            }
        }
    }
    
    func formattedDistance(_ meters: Double) -> String {
        if useMiles {
            let miles = meters / 1609.34
            return String(format: "%.2f", miles) + "mi"
        } else {
            let km = meters / 1000
            return String(format: "%.2f", km) + "km"
        }
    }
    
    func calculatePace(from speedMps: Double, useMiles: Bool) -> String {
        let metersPerUnit = useMiles ? 1609.34 : 1000.0
        let secondsPerUnit = metersPerUnit / speedMps
        let minutes = Int(secondsPerUnit / 60)
        let seconds = Int(secondsPerUnit.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var playerPace: String {
        if isTreadmillMode {
            let minutes = Int(treadmillPace)
            let seconds = Int((treadmillPace * 60).truncatingRemainder(dividingBy: 60))
            return String(format: "%d:%02d", minutes, seconds)
        } else if let speed = locationManager?.currentSpeed, speed > 0 {
            return calculatePace(from: speed, useMiles: useMiles)
        } else {
            return "--:--"
        }
    }
    
    // Returns player's distance covered as a formatted string in km/mi
    var playerDistanceString: String {
        formattedDistance(raceScene.playerDistance)
    }

    // Returns player's progress as a percentage
    var playerProgressPercent: String {
        let progress = (raceScene.playerDistance / raceScene.raceDistance) * 100
        return String(format: "Progress: %.0f%%", progress)
    }

    // Returns player's progress as covered vs total in correct units
    var playerProgressDetail: String {
        let covered = formattedDistance(raceScene.playerDistance)
        let total = formattedDistance(raceScene.raceDistance)
        return "\(covered) / \(total)"
    }

    var leaderboard: [RunnerData] {
        raceScene.leaderboard
    }
    
    var playerHeartbeat: Int {
        return self.heartRate // Return the latest heart rate from the published property
    }
}
