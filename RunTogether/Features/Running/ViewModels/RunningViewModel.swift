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
    @Published var locationManager: LocationManager
    @Published var raceScene: RaceScene
    @Published var heartRate: Int = 0
    private let healthManager = HealthKitManager() // New instance of your HealthKitManager
    private var cancellables = Set<AnyCancellable>()
    
    
    init() {
        locationManager = LocationManager()
        raceScene = RaceScene()
        raceScene.locationManager = locationManager
        
        // Set up observation of raceScene changes
        raceScene.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        // Request HealthKit authorization when the ViewModel is initialized
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
    
    var playerPace: String {
        locationManager.paceString()
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
