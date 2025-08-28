//
//  SupabaseConnection.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/19/25.
//

import Supabase
import SwiftUI

// Connects to DB for authentication and
class SupabaseConnection: ObservableObject {
    let client: SupabaseClient;
    
    init() {
        guard let supabaseURLString = Bundle.main.infoDictionary?["Supabase URL"] as? String,
              let supabaseKey = Bundle.main.infoDictionary?["Supabase Key"] as? String,
              let supabaseURL = URL(string: supabaseURLString) else {
            fatalError("Supabase URL or Key not found in Info.plist. Please ensure SUPABASE_URL and SUPABASE_KEY are set as environment variables in Xcode and linked in Info.plist.")
        }
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }
    
    func signUp(email: String, password: String, username: String) async throws -> User {
        let response = try await self.client.auth.signUp(email: email, password: password, data: ["username": AnyJSON(username)])
        return response.user
    }
    
    func signIn(email: String, password: String) async throws -> User {
        let response = try await self.client.auth.signIn(email: email, password: password)
        return response.user
    }
    
    func signOut() async throws {
        try await self.client.auth.signOut();
    }
    
//    // CRUD OPERATIONS
//    func readItem() async throws {
//        try await client
//            .from("items")
//            .select()
//            .execute()
//    }
//    
//    func createItem(_ item: String) async throws {
//        try await client
//            .from("items")
//            .insert(<#_#>)
//    }
//    
//    func updateItem(_ item: String) async throws {
//        try await client
//            .from("items")
//            .update(<#_#>)
//    }
//    
//    func deleteItem(_ item: String) async throws {
//        try await client
//            .from("items")
//            .delete()
//    }
}
