//
//  UserModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/20/25.
//

import Foundation

struct AppUser: Identifiable {
    let id: String
    var email: String
    var username: String
}

// Basically checks if user id is actually valid
struct Profile: Codable, Identifiable {
    let id: UUID
    let created_at: Date?
    var username: String
    var first_name: String
    var last_name: String
    var location: String?
}
