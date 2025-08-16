//
//  CloudKitConnection.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/11/25.
//

import CloudKit

class CloudKitConnection: ObservableObject {
    let container: CKContainer
    let currUserDatabase: CKDatabase
    
    init() {
        self.container = CKContainer.default()
        self.currUserDatabase = container.publicCloudDatabase
    }
    
    func createRecord() async throws {
        let record = CKRecord(recordType: "User")

        record.setValuesForKeys([
            "name": "Kenneth",
            "country": "US",
            "age": 26
        ])
        
        // Save record to user's specific db
        try await self.currUserDatabase.save(record);
        print("Sign up successful!")
    }
    
    func deleteRecord() async throws {
        let recordID = CKRecord.ID(recordName: "70849A12-AFD2-467F-AEAF-F3C54C177ABA")
        let deletedRecordID = try await currUserDatabase.deleteRecord(withID: recordID)
        print("Record has been deleted: \(deletedRecordID.recordName)")
    }
    
    // Testing pulling all users
    func readRecord() async throws {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "User", predicate: predicate)
        
        // Use the modern async/await API instead of CKQueryOperation
        let (matchResults, _) = try await currUserDatabase.records(matching: query)
        
        var results: [CKRecord] = []
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                results.append(record)
                print("Fetched record: \(record.recordID.recordName), name: \(record["name"] ?? "Unknown")")
            case .failure(let error):
                print("Error fetching record: \(error)")
            }
        }
        
        print("All fetched records:", results)
    }
    
    func updateRecord() async throws {
        // Fetch the record first
        let recordID = CKRecord.ID(recordName: "70849A12-AFD2-467F-AEAF-F3C54C177ABA")
        let record = try await currUserDatabase.record(for: recordID)
        
        // Updated fields
        let name = "John"
        let country = "UK"
        let age = 30
        record["name"] = name as CKRecordValue
        record["country"] = country as CKRecordValue
        record["age"] = age as CKRecordValue
        
        // Save the updated record
        let updatedRecord = try await self.currUserDatabase.save(record)
        print("Record updated: \(updatedRecord.recordID.recordName)")
    }
}
