//
//  LocationManager.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/27/25.
//
import Foundation
import CoreLocation

// For obtaining the live gps
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var currentSpeed: CLLocationSpeed = 0 // meters per second
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 1 // update every meter
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // speed in m/s, fallback to 0 if invalid
        currentSpeed = max(location.speed, 0)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func paceString() -> String {
        guard currentSpeed > 0 else { return "--:--" }
        let paceSecondsPerKm = 1000 / currentSpeed
        let minutes = Int(paceSecondsPerKm / 60)
        let seconds = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
