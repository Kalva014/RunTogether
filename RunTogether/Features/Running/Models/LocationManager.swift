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
    
    /// Returns the pace as a formatted string ("min:sec") using current speed.
    /// - Parameter useMiles: true for miles, false for kilometers
    func paceString(useMiles: Bool = false) -> String {
        guard currentSpeed > 0 else { return "--:--" }
        
        let metersPerUnit = useMiles ? 1609.34 : 1000.0
        let secondsPerUnit = metersPerUnit / currentSpeed
        let minutes = Int(secondsPerUnit / 60)
        let seconds = Int(secondsPerUnit.truncatingRemainder(dividingBy: 60))
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}
