//
//  RaceModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/18/25.
//
import SwiftUI

struct Race: Codable, Identifiable {
    let id: UUID?
    let name: String?
    let mode: String
    let start_time: Date
    let end_time: Date?
    let distance: Double
}

struct RaceParticipants: Codable, Identifiable {
    let id: UUID?
    let created_at: Date
    let user_id: UUID
    let finish_time: String?
    let distance_covered: Double
    let place: Int?
    let average_pace: Double?
    let race_id: UUID
}

struct RaceUpdates: Codable, Identifiable {
    let id: UUID?
    let created_at: Date
    let race_id: UUID
    let user_id: UUID
    let current_distance: Double
    let current_pace: Double
}
