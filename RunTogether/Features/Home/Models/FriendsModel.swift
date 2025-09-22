//
//  FriendsModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/21/25.
//
import Foundation

struct Friend: Codable {
    var id: Int8
    var created_at: String
    var user_id_1: UUID
    var user_id_2: UUID
}
