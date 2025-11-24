//
//  RankingModel.swift
//  RunTogether
//
//  Ranking system for multiplayer races
//

import Foundation

// MARK: - Rank Tiers
enum RankTier: String, Codable, CaseIterable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case platinum = "Platinum"
    case diamond = "Diamond"
    case champion = "Champion"
    
    var numericValue: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 1
        case .gold: return 2
        case .platinum: return 3
        case .diamond: return 4
        case .champion: return 5
        }
    }
    
    var hasDivisions: Bool {
        return self != .champion
    }
    
    var emoji: String {
        switch self {
        case .bronze: return "🥉"
        case .silver: return "🥈"
        case .gold: return "🥇"
        case .platinum: return "💠"
        case .diamond: return "💎"
        case .champion: return "👑"
        }
    }
    
    var descriptor: String {
        switch self {
        case .bronze: return "Rookies finding their stride"
        case .silver: return "Developing runners building consistency"
        case .gold: return "Competitive athletes chasing podiums"
        case .platinum: return "Elite runners with precision pacing"
        case .diamond: return "Top-tier competitors dominating races"
        case .champion: return "Legendary status — LP fuels the global leaderboard"
        }
    }
    
    static func from(numericValue: Int) -> RankTier {
        switch numericValue {
        case 0: return .bronze
        case 1: return .silver
        case 2: return .gold
        case 3: return .platinum
        case 4: return .diamond
        case 5: return .champion
        default: return .bronze
        }
    }
}

// MARK: - Rank Divisions (IV = 4, III = 3, II = 2, I = 1)
enum RankDivision: Int, Codable, CaseIterable {
    case iv = 4
    case iii = 3
    case ii = 2
    case i = 1
    
    var displayName: String {
        switch self {
        case .iv: return "IV"
        case .iii: return "III"
        case .ii: return "II"
        case .i: return "I"
        }
    }
}

// MARK: - Ranked Profile
struct RankedProfile: Codable, Identifiable {
    let id: UUID?
    let user_id: UUID
    var rank_tier: String // "Bronze", "Silver", etc.
    var rank_division: Int? // 4, 3, 2, 1 (or nil for Champion)
    var league_points: Int // LP
    var hidden_mmr: Int? // Optional MMR for better matchmaking
    var top_3_finishes: Int? // Total top 3 finishes in ranked races
    var total_races: Int? // Total ranked races participated in
    let created_at: Date?
    var updated_at: Date?
    
    // Computed properties for easier use
    var tier: RankTier {
        get { RankTier(rawValue: rank_tier) ?? .bronze }
        set { rank_tier = newValue.rawValue }
    }
    
    var division: RankDivision? {
        get { 
            guard let div = rank_division else { return nil }
            return RankDivision(rawValue: div)
        }
        set { rank_division = newValue?.rawValue }
    }
    
    /// Full rank display string (e.g., "Gold II — 64 LP")
    var displayString: String {
        if tier == .champion {
            return "Champion — \(league_points) LP"
        } else if let division = division {
            return "\(tier.rawValue) \(division.displayName) — \(league_points) LP"
        } else {
            return "\(tier.rawValue) — \(league_points) LP"
        }
    }
    
    /// Create a new ranked profile for a new user (starts at Bronze IV, 0 LP)
    static func newProfile(userId: UUID) -> RankedProfile {
        return RankedProfile(
            id: nil,
            user_id: userId,
            rank_tier: RankTier.bronze.rawValue,
            rank_division: RankDivision.iv.rawValue,
            league_points: 0,
            hidden_mmr: 1000, // Starting MMR
            top_3_finishes: 0,
            total_races: 0,
            created_at: nil,
            updated_at: nil
        )
    }
    
    /// Win rate percentage (top 3 finishes / total races)
    var top3Rate: Double {
        guard let races = total_races, races > 0,
              let top3 = top_3_finishes else { return 0.0 }
        return (Double(top3) / Double(races)) * 100.0
    }
}

// MARK: - LP Calculation
struct LPCalculator {
    
    /// Calculate LP change based on finishing position
    /// - Parameters:
    ///   - place: Finishing position (1 = first place)
    ///   - totalRunners: Total number of runners in the race
    /// - Returns: LP change (positive = gain, negative = loss)
    static func calculateLPChange(place: Int, totalRunners: Int) -> Int {
        guard totalRunners > 1 else { return 0 }
        
        let clampedPlace = max(1, min(place, totalRunners))
        let relativeStanding = Double(totalRunners - clampedPlace) / Double(totalRunners - 1) // 0 (last) → 1 (first)
        
        let maxGain = 28.0
        let minLoss = -18.0
        let baseChange = minLoss + relativeStanding * (maxGain - minLoss)
        
        // Smaller lobbies still award LP but with a trimmed scale so 1v1 races matter
        let sizeScale = 0.6 + 0.4 * min(1.0, Double(totalRunners) / 8.0)
        var lp = baseChange * sizeScale
        
        if clampedPlace == 1 {
            lp += 2 // small win bonus
        } else if clampedPlace == 2 && totalRunners >= 3 {
            lp += 1
        }
        
        if clampedPlace == totalRunners && totalRunners > 2 {
            lp -= 1 // discourage consistent last-place finishes
        }
        
        return Int(lp.rounded())
    }
    
    /// Apply LP change and handle promotion/demotion
    /// - Parameters:
    ///   - profile: Current ranked profile
    ///   - lpChange: LP change to apply
    /// - Returns: Updated ranked profile with new rank/division/LP
    static func applyLPChange(to profile: RankedProfile, lpChange: Int) -> RankedProfile {
        var updatedProfile = profile
        var newLP = profile.league_points + lpChange
        var currentTier = profile.tier
        var currentDivision = profile.division
        
        // Handle Champion rank (no divisions)
        if currentTier == .champion {
            // Champion can't be promoted or demoted
            // LP can go negative for leaderboard sorting
            updatedProfile.league_points = newLP
            updatedProfile.updated_at = Date()
            return updatedProfile
        }
        
        // Handle promotion (LP >= 100)
        while newLP >= 100 {
            newLP -= 100
            
            // Promote division
            if let div = currentDivision {
                if div == .i {
                    // Promote to next tier
                    if currentTier.numericValue < RankTier.champion.numericValue {
                        currentTier = RankTier.from(numericValue: currentTier.numericValue + 1)
                        if currentTier == .champion {
                            currentDivision = nil
                        } else {
                            currentDivision = .iv // Reset to IV in new tier
                        }
                    }
                } else {
                    // Promote to next division in same tier
                    currentDivision = RankDivision(rawValue: div.rawValue - 1)
                }
            }
        }
        
        // Handle demotion (LP < 0)
        while newLP < 0 {
            // Can't demote below Bronze IV
            if currentTier == .bronze && currentDivision == .iv {
                newLP = 0
                break
            }
            
            newLP += 100
            
            // Demote division
            if let div = currentDivision {
                if div == .iv {
                    // Demote to previous tier
                    if currentTier.numericValue > 0 {
                        currentTier = RankTier.from(numericValue: currentTier.numericValue - 1)
                        currentDivision = .i // Start at I in lower tier
                    }
                } else {
                    // Demote to next lower division in same tier
                    currentDivision = RankDivision(rawValue: div.rawValue + 1)
                }
            }
        }
        
        updatedProfile.tier = currentTier
        updatedProfile.division = currentDivision
        updatedProfile.league_points = newLP
        updatedProfile.updated_at = Date()
        
        return updatedProfile
    }
}

// MARK: - Matchmaking
struct RankMatchmaking {
    
    /// Check if two players can be matched based on rank tiers
    /// - Parameters:
    ///   - tier1: First player's rank tier
    ///   - tier2: Second player's rank tier
    ///   - maxSpread: Maximum tier difference allowed (default: 1)
    /// - Returns: True if players can be matched
    static func canMatch(tier1: RankTier, tier2: RankTier, maxSpread: Int = 1) -> Bool {
        let diff = abs(tier1.numericValue - tier2.numericValue)
        return diff <= maxSpread
    }
    
    /// Get tier range for matchmaking
    /// - Parameters:
    ///   - tier: Player's current tier
    ///   - spread: Tier spread (default: 1, max: 2)
    /// - Returns: Array of acceptable tiers for matchmaking
    static func getTierRange(for tier: RankTier, spread: Int = 1) -> [RankTier] {
        let minTier = max(0, tier.numericValue - spread)
        let maxTier = min(RankTier.champion.numericValue, tier.numericValue + spread)
        
        var tiers: [RankTier] = []
        for value in minTier...maxTier {
            tiers.append(RankTier.from(numericValue: value))
        }
        return tiers
    }
}

// MARK: - Leaderboard Entry with Ranking
struct RankedLeaderboardEntry: Codable, Identifiable {
    let id: UUID?
    let user_id: UUID
    var rank_tier: String
    var rank_division: Int?
    var league_points: Int
    var top_3_finishes: Int?
    var total_races: Int?
    
    var tier: RankTier {
        RankTier(rawValue: rank_tier) ?? .bronze
    }
    
    var division: RankDivision? {
        guard let div = rank_division else { return nil }
        return RankDivision(rawValue: div)
    }
    
    var displayString: String {
        if tier == .champion {
            return "Champion — \(league_points) LP"
        } else if let division = division {
            return "\(tier.rawValue) \(division.displayName) — \(league_points) LP"
        } else {
            return "\(tier.rawValue) — \(league_points) LP"
        }
    }
    
    /// Top 3 rate percentage
    var top3Rate: Double {
        guard let races = total_races, races > 0,
              let top3 = top_3_finishes else { return 0.0 }
        return (Double(top3) / Double(races)) * 100.0
    }
}

// MARK: - LP Change Result
struct LPChangeResult {
    let oldRank: String
    let newRank: String
    let lpChange: Int
    let promoted: Bool
    let demoted: Bool
    let newLP: Int
    let oldLP: Int
    let tier: RankTier
    let division: RankDivision?
    
    var displayMessage: String {
        if promoted {
            return "Promoted to \(newRank)! (+\(lpChange) LP)"
        } else if demoted {
            return "Demoted to \(newRank) (\(lpChange) LP)"
        } else if lpChange > 0 {
            return "+\(lpChange) LP"
        } else if lpChange < 0 {
            return "\(lpChange) LP"
        } else {
            return "No LP change"
        }
    }
}

