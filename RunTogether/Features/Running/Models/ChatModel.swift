//
//  ChatModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/21/25.
//

import Foundation

struct RaceChatMessage: Codable, Identifiable {
    let id: UUID?
    let race_id: UUID
    let user_id: UUID
    let username: String?
    let message: String
    let created_at: Date?
}
