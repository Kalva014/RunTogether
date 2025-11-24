# Ranking System API Reference

Complete reference for all ranking system methods and models.

---

## Table of Contents

1. [Models](#models)
2. [SupabaseConnection Methods](#supabaseconnection-methods)
3. [ViewModel Methods](#viewmodel-methods)
4. [Integration Examples](#integration-examples)

---

## Models

### RankTier Enum

Represents the six rank tiers in the system.

```swift
enum RankTier: String, Codable, CaseIterable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case platinum = "Platinum"
    case diamond = "Diamond"
    case champion = "Champion"
}
```

**Properties:**
- `numericValue: Int` - Returns 0-5 for sorting
- `hasDivisions: Bool` - Returns false only for Champion
- `from(numericValue: Int) -> RankTier` - Creates tier from numeric value

**Example:**
```swift
let tier = RankTier.gold
print(tier.numericValue) // 2
print(tier.hasDivisions) // true
```

---

### RankDivision Enum

Represents divisions within a tier (IV to I).

```swift
enum RankDivision: Int, Codable, CaseIterable {
    case iv = 4
    case iii = 3
    case ii = 2
    case i = 1
}
```

**Properties:**
- `displayName: String` - Returns Roman numeral representation

**Example:**
```swift
let division = RankDivision.ii
print(division.displayName) // "II"
```

---

### RankedProfile Struct

Main model for user ranking data.

```swift
struct RankedProfile: Codable, Identifiable {
    let id: UUID?
    let user_id: UUID
    var rank_tier: String
    var rank_division: Int?
    var league_points: Int
    var hidden_mmr: Int?
    var total_ranked_wins: Int?
    var total_ranked_losses: Int?
    let created_at: Date?
    var updated_at: Date?
}
```

**Computed Properties:**
- `tier: RankTier` - Get/set tier as enum
- `division: RankDivision?` - Get/set division as enum
- `displayString: String` - Full rank display (e.g., "Gold II — 64 LP")

**Static Methods:**
- `newProfile(userId: UUID) -> RankedProfile` - Creates new profile at Bronze IV, 0 LP

**Example:**
```swift
let profile = RankedProfile.newProfile(userId: userId)
print(profile.displayString) // "Bronze IV — 0 LP"
```

---

### LPCalculator Struct

Utility for calculating LP changes.

```swift
struct LPCalculator {
    static func calculateLPChange(place: Int, totalRunners: Int) -> Int
    static func applyLPChange(to profile: RankedProfile, lpChange: Int) -> RankedProfile
}
```

**Methods:**

#### calculateLPChange

Calculates LP change based on finishing position.

```swift
let lpChange = LPCalculator.calculateLPChange(place: 1, totalRunners: 8)
// Returns: +25 for 1st place
```

**LP Distribution:**
- 1st: +25 LP
- 2nd: +18 LP
- 3rd: +15 LP
- 4th: +12 LP
- 5th: +8 LP
- 6th: +5 LP
- 7th: 0 LP
- 8th: -5 LP
- 9th+: -10 LP

#### applyLPChange

Applies LP change and handles promotion/demotion.

```swift
let updatedProfile = LPCalculator.applyLPChange(to: currentProfile, lpChange: 25)
// Returns new profile with updated rank/division/LP
```

---

### RankMatchmaking Struct

Utility for matchmaking logic.

```swift
struct RankMatchmaking {
    static func canMatch(tier1: RankTier, tier2: RankTier, maxSpread: Int = 1) -> Bool
    static func getTierRange(for tier: RankTier, spread: Int = 1) -> [RankTier]
}
```

**Methods:**

#### canMatch

Checks if two players can be matched.

```swift
let canMatch = RankMatchmaking.canMatch(
    tier1: .gold,
    tier2: .platinum,
    maxSpread: 1
)
// Returns: true (within ±1 tier)
```

#### getTierRange

Gets acceptable tiers for matchmaking.

```swift
let tiers = RankMatchmaking.getTierRange(for: .gold, spread: 1)
// Returns: [.silver, .gold, .platinum]
```

---

### LPChangeResult Struct

Result of a rank update operation.

```swift
struct LPChangeResult {
    let oldRank: String
    let newRank: String
    let lpChange: Int
    let promoted: Bool
    let demoted: Bool
    var displayMessage: String
}
```

**Example:**
```swift
print(result.displayMessage)
// "Promoted to Gold II! (+25 LP)"
// or "+18 LP"
// or "Demoted to Silver I (-10 LP)"
```

---

### RankedLeaderboardEntry Struct

Leaderboard entry with ranking info.

```swift
struct RankedLeaderboardEntry: Codable, Identifiable {
    let id: UUID?
    let user_id: UUID
    var rank_tier: String
    var rank_division: Int?
    var league_points: Int
    var total_ranked_wins: Int?
    var total_ranked_losses: Int?
}
```

**Computed Properties:**
- `tier: RankTier`
- `division: RankDivision?`
- `displayString: String`

---

## SupabaseConnection Methods

All ranking-related methods in `SupabaseConnection.swift`.

### Get Ranked Profile

#### getRankedProfile() -> RankedProfile?

Gets or creates ranked profile for current user.

```swift
let profile = try await supabaseConnection.getRankedProfile()
print(profile?.displayString ?? "No profile")
```

**Returns:** `RankedProfile?` - User's ranked profile (creates new if doesn't exist)  
**Throws:** Database errors

---

#### getRankedProfile(userId: UUID) -> RankedProfile?

Gets ranked profile for specific user.

```swift
let profile = try await supabaseConnection.getRankedProfile(userId: friendId)
```

**Parameters:**
- `userId: UUID` - User ID to fetch

**Returns:** `RankedProfile?`  
**Throws:** Database errors

---

### Update Rank

#### updateRankAfterRace(userId: UUID, place: Int, totalRunners: Int) -> LPChangeResult

Updates rank after a race completes.

```swift
let result = try await supabaseConnection.updateRankAfterRace(
    userId: userId,
    place: 1,
    totalRunners: 8
)
print(result.displayMessage) // "Promoted to Gold II! (+25 LP)"
```

**Parameters:**
- `userId: UUID` - User to update
- `place: Int` - Finishing position (1-based)
- `totalRunners: Int` - Total number of participants

**Returns:** `LPChangeResult` - Details of the rank change  
**Throws:** Database errors

**Side Effects:**
- Updates `Ranked_Profiles` table
- Increments win/loss count
- Handles promotion/demotion automatically

---

### Leaderboards

#### fetchRankedLeaderboard(page: Int = 0, pageSize: Int = 10) -> [RankedLeaderboardEntry]

Fetches global ranked leaderboard.

```swift
let leaderboard = try await supabaseConnection.fetchRankedLeaderboard(
    page: 0,
    pageSize: 20
)
```

**Parameters:**
- `page: Int` - Page number (0-based)
- `pageSize: Int` - Entries per page

**Returns:** `[RankedLeaderboardEntry]` - Sorted by rank (best to worst)  
**Throws:** Database errors

**Sorting Order:**
1. Rank tier (Champion > Diamond > ... > Bronze)
2. Division (I > II > III > IV)
3. LP (higher > lower)

---

#### fetchFriendsRankedLeaderboard() -> [RankedLeaderboardEntry]

Fetches ranked leaderboard for friends only.

```swift
let friendsLeaderboard = try await supabaseConnection.fetchFriendsRankedLeaderboard()
```

**Returns:** `[RankedLeaderboardEntry]` - Friends + current user, sorted by rank  
**Throws:** Database errors

---

#### getMyRankedPosition() -> Int?

Gets current user's position on global ranked leaderboard.

```swift
if let position = try await supabaseConnection.getMyRankedPosition() {
    print("You are rank #\(position) globally!")
}
```

**Returns:** `Int?` - 1-based ranking position  
**Throws:** Database errors

---

### Matchmaking

#### findRankedMatches(mode: String, distance: Double, useMiles: Bool, maxSpread: Int = 1) -> [Race]

Finds available ranked races for matchmaking.

```swift
let availableRaces = try await supabaseConnection.findRankedMatches(
    mode: "ranked",
    distance: 1609.34, // 1 mile in meters
    useMiles: true,
    maxSpread: 1 // ±1 tier
)
```

**Parameters:**
- `mode: String` - Race mode
- `distance: Double` - Race distance in meters
- `useMiles: Bool` - Whether using miles
- `maxSpread: Int` - Maximum tier difference (1 = ±1 tier, 2 = ±2 tiers)

**Returns:** `[Race]` - Available races matching criteria  
**Throws:** Database errors

**Logic:**
- Filters races by mode and distance
- Checks age (max 5 minutes old)
- Validates rank compatibility with existing participants
- Returns only races where all participants are within acceptable rank range

---

#### createRankedRace(name: String?, mode: String, start_time: Date, distance: Double, useMiles: Bool) -> Race?

Creates a new ranked race.

```swift
let race = try await supabaseConnection.createRankedRace(
    name: "Ranked 1 Mile",
    mode: "ranked",
    start_time: Date(),
    distance: 1609.34,
    useMiles: true
)
```

**Parameters:**
- `name: String?` - Optional race name
- `mode: String` - Should be "ranked"
- `start_time: Date` - Race start time
- `distance: Double` - Distance in meters
- `useMiles: Bool` - Whether using miles

**Returns:** `Race?` - Created race  
**Throws:** Database errors

---

#### joinRankedRace(raceId: UUID, maxParticipants: Int) -> UUID?

Joins a ranked race with validation.

```swift
if let joinedRaceId = try await supabaseConnection.joinRankedRace(
    raceId: raceId,
    maxParticipants: 8
) {
    print("Joined ranked race!")
}
```

**Parameters:**
- `raceId: UUID` - Race to join
- `maxParticipants: Int` - Maximum allowed participants

**Returns:** `UUID?` - Race ID if successfully joined  
**Throws:** Database errors

**Validation:**
- Checks rank compatibility with existing participants
- Validates maxSpread of ±2 tiers
- Returns nil if rank mismatch

---

## ViewModel Methods

### LeaderboardTabViewModel

#### Properties

```swift
@Published var showRanked: Bool = false // Toggle ranked/casual
@Published var showFriendsOnly: Bool = false // Toggle global/friends
@Published var rankedLeaderboardEntries: [RankedLeaderboardEntry] = []
@Published var myRankedProfile: RankedProfile?
@Published var myRankedPosition: Int?
```

#### Methods

##### toggleLeaderboardType(appEnvironment: AppEnvironment)

Switches between ranked and casual leaderboards.

```swift
await viewModel.toggleLeaderboardType(appEnvironment: appEnvironment)
```

##### toggleFriendsOnly(appEnvironment: AppEnvironment)

Switches between global and friends leaderboards.

```swift
await viewModel.toggleFriendsOnly(appEnvironment: appEnvironment)
```

##### rankDisplay(for userId: UUID) -> String?

Gets rank display string for a user.

```swift
if let rank = viewModel.rankDisplay(for: userId) {
    Text(rank) // "Gold II — 64 LP"
}
```

##### myRankDisplay: String?

Gets current user's rank display.

```swift
if let myRank = viewModel.myRankDisplay {
    Text("Your Rank: \(myRank)")
}
```

---

### RaceResultsViewModel

#### Properties

```swift
@Published var lpChangeResult: LPChangeResult?
@Published var showLPChange: Bool = false
```

#### Methods

##### calculateLPChange(currentUserPlace: Int)

Calculates and updates LP after a ranked race.

```swift
// After race completes
let place = viewModel.getCurrentUserPlace(username: username)
if let place = place {
    await viewModel.calculateLPChange(currentUserPlace: place)
}
```

**Parameters:**
- `currentUserPlace: Int` - User's finishing position

**Side Effects:**
- Updates `lpChangeResult`
- Sets `showLPChange` to true

##### getCurrentUserPlace(username: String) -> Int?

Gets user's finishing position from leaderboard.

```swift
if let place = viewModel.getCurrentUserPlace(username: "player1") {
    print("Finished in place \(place)")
}
```

**Parameters:**
- `username: String` - Username to find

**Returns:** `Int?` - 1-based finishing position (only finished runners)

---

## Integration Examples

### Example 1: Display User's Rank in Profile

```swift
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var rankedProfile: RankedProfile?
    
    var body: some View {
        VStack {
            if let profile = rankedProfile {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ranked Status")
                        .font(.headline)
                    
                    Text(profile.displayString)
                        .font(.title2)
                        .bold()
                    
                    HStack {
                        Text("Wins: \(profile.total_ranked_wins ?? 0)")
                        Text("Losses: \(profile.total_ranked_losses ?? 0)")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .task {
            rankedProfile = try? await appEnvironment.supabaseConnection.getRankedProfile()
        }
    }
}
```

---

### Example 2: Show LP Change After Race

```swift
import SwiftUI

struct RaceResultsView: View {
    @StateObject var viewModel: RaceResultsViewModel
    @EnvironmentObject var appEnvironment: AppEnvironment
    let username: String
    
    var body: some View {
        VStack {
            // Leaderboard
            List(viewModel.leaderboard) { runner in
                // ... runner display
            }
            
            // LP Change Display
            if viewModel.showLPChange, let lpResult = viewModel.lpChangeResult {
                VStack(spacing: 12) {
                    Text("Rank Update")
                        .font(.headline)
                    
                    Text(lpResult.displayMessage)
                        .font(.title3)
                        .bold()
                        .foregroundColor(lpResult.promoted ? .green : 
                                       lpResult.demoted ? .red : .blue)
                    
                    if lpResult.promoted {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                    } else if lpResult.demoted {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Text("Previous:")
                        Text(lpResult.oldRank)
                    }
                    
                    HStack {
                        Text("Current:")
                        Text(lpResult.newRank)
                            .bold()
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .task {
            // After race finishes, calculate LP
            if let place = viewModel.getCurrentUserPlace(username: username) {
                await viewModel.calculateLPChange(currentUserPlace: place)
            }
        }
    }
}
```

---

### Example 3: Ranked Matchmaking

```swift
import SwiftUI

struct RankedMatchmakingView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var availableRaces: [Race] = []
    @State private var myRank: String = ""
    @State private var isSearching = false
    
    let distance: Double = 1609.34 // 1 mile
    
    var body: some View {
        VStack(spacing: 20) {
            // Display user's current rank
            Text("Your Rank: \(myRank)")
                .font(.title2)
                .bold()
            
            // Search button
            Button("Find Ranked Match") {
                Task {
                    await findMatch()
                }
            }
            .disabled(isSearching)
            
            // Available races
            if !availableRaces.isEmpty {
                List(availableRaces) { race in
                    Button {
                        Task {
                            await joinRace(race)
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Race \(race.id?.uuidString.prefix(8) ?? "")")
                            Text("Started \(race.start_time, style: .relative)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else if isSearching {
                ProgressView("Searching for matches...")
            } else {
                Text("No available matches")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .task {
            // Load user's rank
            if let profile = try? await appEnvironment.supabaseConnection.getRankedProfile() {
                myRank = profile.displayString
            }
        }
    }
    
    func findMatch() async {
        isSearching = true
        defer { isSearching = false }
        
        do {
            // Try ±1 tier first
            var races = try await appEnvironment.supabaseConnection.findRankedMatches(
                mode: "ranked",
                distance: distance,
                useMiles: true,
                maxSpread: 1
            )
            
            // If no matches, expand to ±2 tiers
            if races.isEmpty {
                races = try await appEnvironment.supabaseConnection.findRankedMatches(
                    mode: "ranked",
                    distance: distance,
                    useMiles: true,
                    maxSpread: 2
                )
            }
            
            // If still no matches, create new race
            if races.isEmpty {
                if let newRace = try await appEnvironment.supabaseConnection.createRankedRace(
                    mode: "ranked",
                    start_time: Date(),
                    distance: distance,
                    useMiles: true
                ) {
                    races = [newRace]
                }
            }
            
            availableRaces = races
        } catch {
            print("Error finding matches: \(error)")
        }
    }
    
    func joinRace(_ race: Race) async {
        guard let raceId = race.id else { return }
        
        do {
            if let _ = try await appEnvironment.supabaseConnection.joinRankedRace(
                raceId: raceId,
                maxParticipants: 8
            ) {
                print("Successfully joined ranked race!")
                // Navigate to race view
            }
        } catch {
            print("Error joining race: \(error)")
        }
    }
}
```

---

### Example 4: Ranked Leaderboard View

```swift
import SwiftUI

struct RankedLeaderboardView: View {
    @StateObject var viewModel = LeaderboardTabViewModel()
    @EnvironmentObject var appEnvironment: AppEnvironment
    
    var body: some View {
        VStack {
            // Toggle buttons
            HStack {
                Button(viewModel.showRanked ? "Casual" : "Ranked") {
                    Task {
                        await viewModel.toggleLeaderboardType(appEnvironment: appEnvironment)
                    }
                }
                .buttonStyle(.bordered)
                
                Button(viewModel.showFriendsOnly ? "Global" : "Friends") {
                    Task {
                        await viewModel.toggleFriendsOnly(appEnvironment: appEnvironment)
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            // My stats
            if viewModel.showRanked, let myRank = viewModel.myRankDisplay {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Your Rank")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(myRank)
                            .font(.title3)
                            .bold()
                    }
                    
                    Spacer()
                    
                    if let position = viewModel.myRankedPosition {
                        VStack(alignment: .trailing) {
                            Text("Position")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("#\(position)")
                                .font(.title3)
                                .bold()
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Leaderboard
            List {
                ForEach(Array(viewModel.rankedLeaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                    HStack {
                        // Rank number
                        Text("#\(index + 1)")
                            .font(.headline)
                            .frame(width: 40)
                        
                        // Username
                        Text(viewModel.username(for: entry.user_id))
                            .font(.body)
                        
                        Spacer()
                        
                        // Rank display
                        Text(entry.displayString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .task {
            await viewModel.refresh(appEnvironment: appEnvironment)
        }
    }
}
```

---

### Example 5: Complete Ranked Race Flow

```swift
// 1. Before starting race - check if ranked
let raceDetails = try await supabaseConnection.getRaceDetails(raceId: raceId)
let isRanked = raceDetails.mode == "ranked"

// 2. Initialize race results view model
let viewModel = RaceResultsViewModel(
    initialLeaderboard: leaderboard,
    raceId: raceId,
    useMiles: useMiles,
    isRankedRace: isRanked // Pass ranked status
)

// 3. After race completes - update ranks for all participants
if isRanked {
    let participants = try await supabaseConnection.client
        .from("Race_Participants")
        .select()
        .eq("race_id", value: raceId.uuidString)
        .execute()
        .value as [RaceParticipants]
    
    // Sort by finish time to determine places
    let sortedParticipants = participants
        .filter { $0.finish_time != nil }
        .sorted { p1, p2 in
            // Sort by finish time
            return (p1.finish_time ?? "") < (p2.finish_time ?? "")
        }
    
    // Update ranks for all participants
    for (index, participant) in sortedParticipants.enumerated() {
        let place = index + 1
        _ = try? await supabaseConnection.updateRankAfterRace(
            userId: participant.user_id,
            place: place,
            totalRunners: sortedParticipants.count
        )
    }
}

// 4. Display LP changes to current user
if let place = viewModel.getCurrentUserPlace(username: currentUsername) {
    await viewModel.calculateLPChange(currentUserPlace: place)
}
```

---

## Error Handling

### Common Errors

1. **User not authenticated**
```swift
guard let userId = supabaseConnection.currentUserId else {
    // Handle: User must be signed in
    return
}
```

2. **Ranked profile not found**
```swift
guard let profile = try await supabaseConnection.getRankedProfile() else {
    // Handle: Profile should auto-create, but check database
    return
}
```

3. **Rank mismatch in matchmaking**
```swift
if let raceId = try await supabaseConnection.joinRankedRace(...) {
    // Success
} else {
    // Handle: Rank mismatch or race full
    print("Unable to join race - rank mismatch or race full")
}
```

---

## Best Practices

1. **Always check if race is ranked before updating LP**
```swift
if raceDetails.mode == "ranked" {
    await updateRanks()
}
```

2. **Cache ranked profiles to reduce database calls**
```swift
private var profileCache: [UUID: RankedProfile] = [:]
```

3. **Update ranks only after race fully completes**
```swift
// Wait for all participants to finish
let allFinished = participants.allSatisfy { $0.finish_time != nil }
if allFinished {
    await updateRanks()
}
```

4. **Show loading states during rank updates**
```swift
@State private var isUpdatingRank = false

Task {
    isUpdatingRank = true
    defer { isUpdatingRank = false }
    await calculateLPChange()
}
```

---

## Testing

### Unit Test Example

```swift
import XCTest

class RankingSystemTests: XCTestCase {
    func testLPCalculation() {
        let lpChange1st = LPCalculator.calculateLPChange(place: 1, totalRunners: 8)
        XCTAssertEqual(lpChange1st, 25)
        
        let lpChange2nd = LPCalculator.calculateLPChange(place: 2, totalRunners: 8)
        XCTAssertEqual(lpChange2nd, 18)
    }
    
    func testPromotion() {
        var profile = RankedProfile.newProfile(userId: UUID())
        profile.league_points = 95
        
        let updated = LPCalculator.applyLPChange(to: profile, lpChange: 25)
        
        XCTAssertEqual(updated.tier, .bronze)
        XCTAssertEqual(updated.division, .iii) // Promoted from IV to III
        XCTAssertEqual(updated.league_points, 20) // 95 + 25 - 100 = 20
    }
    
    func testMatchmaking() {
        let canMatch = RankMatchmaking.canMatch(
            tier1: .gold,
            tier2: .platinum,
            maxSpread: 1
        )
        XCTAssertTrue(canMatch)
        
        let cannotMatch = RankMatchmaking.canMatch(
            tier1: .bronze,
            tier2: .diamond,
            maxSpread: 1
        )
        XCTAssertFalse(cannotMatch)
    }
}
```

---

## Version History

- **v1.0** (November 2025): Initial release

---

For setup instructions, see [RANKING_SYSTEM_SETUP.md](RANKING_SYSTEM_SETUP.md)

