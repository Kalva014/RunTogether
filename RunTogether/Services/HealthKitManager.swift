//
//  HealthKitManager.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/9/25.
//

import HealthKit

class HealthKitManager {
    let healthStore = HKHealthStore()
    
    // Request permission from the user
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let typesToRead: Set<HKObjectType> = [heartRateType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error = error {
                print("Error requesting authorization: \(error.localizedDescription)")
            }
            completion(success)
        }
    }
    
    // Reads heart rate data from HealthKit and sends updates via a closure
    func readHeartRate(updateHandler: @escaping (Double?) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            updateHandler(nil)
            return
        }
        
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { _, _, error in
            if error == nil {
                // When new data is available, fetch the most recent one
                self.fetchLatestHeartRate(updateHandler: updateHandler)
            }
        }
        
        healthStore.execute(query)
        
        // Immediately fetch the latest heart rate to get an initial value
        fetchLatestHeartRate(updateHandler: updateHandler)
    }
    
    private func fetchLatestHeartRate(updateHandler: @escaping (Double?) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            updateHandler(nil)
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let heartRateSample = samples?.first as? HKQuantitySample, error == nil else {
                print("Error fetching heart rate sample: \(String(describing: error))")
                updateHandler(nil)
                return
            }
            
            let heartRateValue = heartRateSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            updateHandler(heartRateValue)
        }
        
        healthStore.execute(query)
    }
}
