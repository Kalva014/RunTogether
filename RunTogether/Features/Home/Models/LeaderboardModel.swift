//
//  LeaderboardModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/21/25.
//

import Foundation

struct GlobalLeaderboardEntry: Codable, Identifiable {
    let id: UUID?
    let user_id: UUID
    let total_races_completed: Double?
    let total_distance_covered: Double?
    let top_three_finishes: Int?
}
