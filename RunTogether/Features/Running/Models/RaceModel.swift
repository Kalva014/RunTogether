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
    let use_miles: Bool
    
    // Default initializer
    init(id: UUID?, name: String?, mode: String, start_time: Date, end_time: Date?, distance: Double, use_miles: Bool) {
        self.id = id
        self.name = name
        self.mode = mode
        self.start_time = start_time
        self.end_time = end_time
        self.distance = distance
        self.use_miles = use_miles
    }
    
    // Custom date decoding to handle incomplete date formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        mode = try container.decode(String.self, forKey: .mode)
        distance = try container.decode(Double.self, forKey: .distance)
        use_miles = try container.decode(Bool.self, forKey: .use_miles)
        
        // Handle start_time with flexible date parsing
        if let startTimeString = try? container.decode(String.self, forKey: .start_time) {
            start_time = Self.parseDate(from: startTimeString) ?? Date()
        } else {
            start_time = try container.decode(Date.self, forKey: .start_time)
        }
        
        // Handle end_time with flexible date parsing
        if let endTimeString = try? container.decodeIfPresent(String.self, forKey: .end_time) {
            end_time = Self.parseDate(from: endTimeString)
        } else {
            end_time = try container.decodeIfPresent(Date.self, forKey: .end_time)
        }
    }
    
    private static func parseDate(from string: String) -> Date? {
        let formatters = [
            // Full ISO8601 with fractional seconds
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter
            }(),
            // ISO8601 without fractional seconds
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                return formatter
            }(),
            // Standard ISO8601
            ISO8601DateFormatter(),
            // Date only format (add time component)
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let dateFormatter = formatter as? DateFormatter {
                if let date = dateFormatter.date(from: string) {
                    return date
                }
            } else if let iso8601Formatter = formatter as? ISO8601DateFormatter {
                if let date = iso8601Formatter.date(from: string) {
                    return date
                }
            }
        }
        
        print("⚠️ Could not parse date: '\(string)'")
        return nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, mode, start_time, end_time, distance, use_miles
    }
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
