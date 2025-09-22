//
//  RunClubModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/21/25.
//

import Foundation

struct RunClub: Codable, Identifiable {
    let id: Int?
    let created_at: Date
    let name: String
    let owner: UUID?
}

struct RunClubMember: Codable {
    let joined_at: Date
    let user_id: UUID
    let group_id: String
}
