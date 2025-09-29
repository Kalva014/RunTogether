//
//  SupabaseConnection.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/19/25.
//

import Supabase
import SwiftUI

/// Connects to DB for authentication and multiplayer
class SupabaseConnection: ObservableObject {
    // MARK: - Initialization
    let client: SupabaseClient
    
    @Published var currentUserId: UUID?
    @Published var currentChannel: RealtimeChannelV2?
    
    init() {
        guard let supabaseURLString = Bundle.main.infoDictionary?["Supabase URL"] as? String,
              let supabaseKey = Bundle.main.infoDictionary?["Supabase Key"] as? String,
              let supabaseURL = URL(string: supabaseURLString) else {
            fatalError("Supabase URL or Key not found in Info.plist.")
        }
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                db: .init(schema: "public")
            )
        )
        
        self.currentUserId = self.client.auth.currentUser?.id
    }
    
    // MARK: - Profile Management
    func createProfile(username: String, first_name: String, last_name: String, location: String?) async throws {
        guard let userId = self.currentUserId else { return }
        
        let newRowData = Profile(
            id: userId,
            created_at: nil,
            username: username,
            first_name: first_name,
            last_name: last_name,
            location: location
        )
        
        let res = try await self.client
            .from("Profiles")
            .insert(newRowData)
            .execute()
        
        print("Profile was created with the following status code: \(res.status)")
    }
    
    func updateProfile(username: String? = nil, firstName: String? = nil, lastName: String? = nil, location: String? = nil) async throws {
        guard let userId = self.currentUserId else { return }
        
        var updatesDict: [String: String] = [:]
        if let username = username, !username.isEmpty { updatesDict["username"] = username }
        if let firstName = firstName, !firstName.isEmpty { updatesDict["first_name"] = firstName }
        if let lastName = lastName, !lastName.isEmpty { updatesDict["last_name"] = lastName }
        if let location = location, !location.isEmpty { updatesDict["location"] = location }
        
        guard !updatesDict.isEmpty else { return }
        
        try await self.client
            .from("Profiles")
            .update(updatesDict)
            .eq("id", value: userId.uuidString)
            .execute()
    }
    
    // MARK: - Authentication
    func signUp(email: String, password: String, username: String) async throws -> User {
        let response = try await self.client.auth.signUp(
            email: email,
            password: password,
            data: ["username": AnyJSON(username)]
        )
        self.currentUserId = response.user.id
        return response.user
    }
    
    func signIn(email: String, password: String) async throws -> User {
        let response = try await self.client.auth.signIn(email: email, password: password)
        self.currentUserId = response.user.id
        return response.user
    }
    
    func signOut() async throws {
        try await self.client.auth.signOut()
        self.currentUserId = nil
    }
    
    // MARK: - Multiplayer Methods
    func createRace(name: String, mode: String, start_time: Date) async throws -> Race {
        guard let userId = self.currentUserId else {
            throw NSError(domain: "SupabaseConnection", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        // Create race
        let brandNewRace = Race(
            id: nil,
            name: name,
            mode: mode,
            start_time: start_time,
            end_time: nil
        )
        
        let newRace: Race = try await self.client
            .from("Races")
            .insert(brandNewRace)
            .select()
            .execute()
            .value
        
        // Add user as participant
        let participant = RaceParticipants(
            id: newRace.id!,
            created_at: Date(),
            user_id: userId,
            finish_time: nil,
            distance_covered: 0.0,
            place: nil,
            average_pace: nil
        )
        
        _ = try await self.client
            .from("Race_Participants")
            .insert(participant)
            .execute()
        
        return newRace
    }
    
    func leaveRace() async {
        if let currentChannel = currentChannel {
            await currentChannel.unsubscribe()
            self.currentChannel = nil
        }
    }
    
    func joinRaceWithCap(raceId: UUID, maxParticipants: Int) async throws {
        guard let userId = self.currentUserId else {
            throw NSError(domain: "SupabaseConnection", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        let currNumParticipants = try await self.client
            .from("Race_Participants")
            .select("race_id", head: true, count: CountOption.exact)
            .eq("race_id", value: raceId.uuidString)
            .execute()
            .count
        
        guard currNumParticipants! < maxParticipants else {
            print("Race full")
            return
        }
        
        let participant = RaceParticipants(
            id: raceId,
            created_at: Date(),
            user_id: userId,
            finish_time: nil,
            distance_covered: 0.0,
            place: nil,
            average_pace: nil
        )
        
        _ = try await self.client
            .from("Race_Participants")
            .insert(participant)
            .execute()
        
        print("Joined race \(raceId)")
    }
    
    func joinRandomRace(mode: String, start_time: Date, maxParticipants: Int) async throws {
        let races: [Race] = try await self.client
            .from("Races")
            .select()
            .is("end_time", value: nil)
            .execute()
            .value
        
        for race in races.shuffled() {
            do {
                try await joinRaceWithCap(raceId: race.id!, maxParticipants: maxParticipants)
                print("Joined race \(race.id!)")
                return
            } catch { continue }
        }
        
        _ = try await createRace(name: "", mode: mode, start_time: start_time)
    }
    
    // MARK: - Race Updates
    func sendRaceUpdate(raceId: UUID, distance: Double, pace: Double) async throws {
        guard let userId = self.currentUserId else { return }
        
        let update = RaceUpdates(
            id: nil,
            created_at: Date(),
            race_id: raceId,
            user_id: userId,
            current_distance: distance,
            current_pace: pace
        )
        
        _ = try await self.client
            .from("Race_Updates")
            .insert(update)
            .execute()
        
        // Automatically check if the race is finished
        try await checkIfRaceFinished(raceId: raceId)
    }
    
    func subscribeToRaceUpdates(raceId: UUID) {
        let channel = client.channel("race_updates:\(raceId)")
        self.currentChannel = channel
        
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "Race_Updates"
        )
        
        Task { [weak self] in
            guard let self = self else { return }
            
            try await channel.subscribeWithError()
            
            for await insert in insertions {
                print("Race update received: \(insert.record)")
                // Update UI state here
                // You can access the inserted record data through insert.record
            }
            
            // If we exit the loop, it means the channel was closed/disconnected
            guard let userId = self.currentUserId else { return }
            try? await self.markParticipantDisconnected(raceId: raceId, userId: userId)
        }
    }
    
    // MARK: - Race Completion
    func checkIfRaceFinished(raceId: UUID) async throws {
        let participants: [RaceParticipants] = try await self.client
            .from("Race_Participants")
            .select()
            .eq("race_id", value: raceId.uuidString)
            .execute()
            .value
        
        let allFinished = participants.allSatisfy { $0.finish_time != nil }
        
        if allFinished {
            try await self.client
                .from("Races")
                .update(["end_time": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: raceId.uuidString)
                .execute()
            
            // Cleanup race updates
            try await self.client
                .from("Race_Updates")
                .delete()
                .eq("race_id", value: raceId.uuidString)
                .execute()
            
            await leaveRace()
            print("Race \(raceId) finished & cleaned up.")
        }
    }
    
    func markParticipantDisconnected(raceId: UUID, userId: UUID) async throws {
        let rowData: [String: AnyJSON] = [
            "finish_time": "N/A", // THIS IS SUPPOSED TO BE A STRING BUT IT IS TRIPPING
            "distance_covered": 0.0,
            "average_pace": 0.0
        ]
        
        _ = try await client
            .from("Race_Participants")
            .update(rowData)
            .eq("race_id", value: raceId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        print("User \(userId) disconnected, marked as finished/N/A")
        try await checkIfRaceFinished(raceId: raceId)
    }
    
    func markParticipantFinished(raceId: UUID, distance: Double, pace: Double, finishPlace: Int) async throws {
        guard let userId = self.currentUserId else { return }
        
        // Correctly wrap each value in its AnyJSON enum case
       let rowData: [String: AnyJSON] = [
           "finish_time": AnyJSON.string(Date().ISO8601Format()), // Convert Date to ISO 8601 string
           "distance_covered": AnyJSON.double(distance), // Use AnyJSON.double
           "average_pace": AnyJSON.double(pace),       // Use AnyJSON.double
           "place": AnyJSON.integer(finishPlace)            // Use AnyJSON.int
       ]


        // 1️⃣ Update participant as finished in Race_Participants
        _ = try await client
            .from("Race_Participants")
            .update(rowData)
            .eq("race_id", value: raceId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        print("User \(userId) marked as finished in race \(raceId) with place \(finishPlace).")

        // 2️⃣ Update global leaderboard
        let finishedInTopThree = finishPlace <= 3
        try await updateGlobalLeaderboard(userId: userId, distance: distance, finishedInTopThree: finishedInTopThree)
        
        print("Global leaderboard updated for user \(userId).")

        // 3️⃣ Check if race is complete
        try await checkIfRaceFinished(raceId: raceId)
    }

    
    
    // MARK: - Friend Management

    /// Adds a friend by their username
    func addFriend(username: String) async throws {
        guard let userId = self.currentUserId else { return }

        // Look up friend by username
        let users: [Profile] = try await client
            .from("Profiles")
            .select()
            .eq("username", value: username)
            .execute()
            .value ?? []

        guard let friend = users.first else {
            print("User with username \(username) not found")
            return
        }

        // Prevent adding yourself
        guard friend.id != userId else {
            print("Cannot add yourself as a friend")
            return
        }

        // Check if friendship already exists (either direction)
        let existing: [Friend] = try await client
            .from("Friends")
            .select()
            .or("""
                (user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(friend.id.uuidString)),
                (user_id_1.eq.\(friend.id.uuidString),user_id_2.eq.\(userId.uuidString))
            """)
            .execute()
            .value ?? []

        guard existing.isEmpty else {
            print("Friendship already exists")
            return
        }

        // Insert new friendship
        _ = try await client
            .from("Friends")
            .insert([
                "user_id_1": userId.uuidString,
                "user_id_2": friend.id.uuidString
            ])
            .execute()

        print("Friend added: \(username)")
    }

    /// Removes a friend by their username
    func removeFriend(username: String) async throws {
        guard let userId = self.currentUserId else { return }

        let users: [Profile] = try await client
            .from("Profiles")
            .select()
            .eq("username", value: username)
            .execute()
            .value ?? []

        guard let friend = users.first else {
            print("User with username \(username) not found")
            return
        }

        // Delete friendship (both directions)
        _ = try await client
            .from("Friends")
            .delete()
            .or("""
                (user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(friend.id.uuidString)),
                (user_id_1.eq.\(friend.id.uuidString),user_id_2.eq.\(userId.uuidString))
            """)
            .execute()

        print("Friend removed: \(username)")
    }

    /// Lists all friends for the current user
    func listFriends() async throws -> [String] {
        guard let userId = self.currentUserId else { return [] }

        let friends: [Friend] = try await client
            .from("Friends")
            .select()
            .or("""
                user_id_1.eq.\(userId.uuidString),
                user_id_2.eq.\(userId.uuidString)
            """)
            .execute()
            .value ?? []

        var friendIds: [UUID] = []

        for f in friends {
            if f.user_id_1 != userId { friendIds.append(f.user_id_1) }
            if f.user_id_2 != userId { friendIds.append(f.user_id_2) }
        }

        if friendIds.isEmpty { return [] }

        let profiles: [Profile] = try await client
            .from("Profiles")
            .select()
            .in("id", values: friendIds.map { $0.uuidString })
            .execute()
            .value ?? []

        return profiles.compactMap { $0.username }
    }

    // MARK: - Run Club Management
    /// Create a new run club
    func createRunClub(name: String) async throws {
        guard let userId = self.currentUserId else { return }

        // Check if club already exists
        let existing: [RunClub] = try await client
            .from("Run_Clubs")
            .select()
            .eq("name", value: name)
            .execute()
            .value ?? []

        guard existing.isEmpty else {
            print("Run club \(name) already exists")
            return
        }

        // Insert new club
        _ = try await client
            .from("Run_Clubs")
            .insert([
                "name": name,
                "owner": userId.uuidString
            ])
            .execute()

        print("Run club \(name) created!")
    }

    /// Join a run club by name
    func joinRunClub(name: String) async throws {
        guard let userId = self.currentUserId else { return }

        // Check if the user is already a member
        let existing: [RunClubMember] = try await client
            .from("Run_Club_Members")
            .select()
            .eq("group_id", value: name)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value ?? []

        guard existing.isEmpty else {
            print("Already a member of \(name)")
            return
        }

        // Insert membership
        _ = try await client
            .from("Run_Club_Members")
            .insert([
                "user_id": userId.uuidString,
                "group_id": name
            ])
            .execute()

        print("Joined run club \(name)")
    }

    /// Leave a run club by name
    func leaveRunClub(name: String) async throws {
        guard let userId = self.currentUserId else { return }

        _ = try await client
            .from("Run_Club_Members")
            .delete()
            .eq("group_id", value: name)
            .eq("user_id", value: userId.uuidString)
            .execute()

        print("Left run club \(name)")
    }

    /// List all members of a run club
    func listRunClubMembers(name: String) async throws -> [String] {
        let members: [RunClubMember] = try await client
            .from("Run_Club_Members")
            .select()
            .eq("group_id", value: name)
            .execute()
            .value ?? []

        let userIds = members.map { $0.user_id }

        if userIds.isEmpty { return [] }

        // Fetch usernames from Profiles
        let profiles: [Profile] = try await client
            .from("Profiles")
            .select()
            .in("id", values: userIds.map { $0.uuidString })
            .execute()
            .value ?? []

        return profiles.compactMap { $0.username }
    }

    /// List all run clubs the current user belongs to
    func listMyRunClubs() async throws -> [String] {
        guard let userId = self.currentUserId else { return [] }

        let memberships: [RunClubMember] = try await client
            .from("Run_Club_Members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value ?? []

        return memberships.map { $0.group_id }
    }
    
    // MARK: - Live Post Race Chat
    @Published var currentMessages: [RaceChatMessage] = []
    private var chatChannel: RealtimeChannelV2?

    /// Send a chat message
    func sendMessage(raceId: UUID, userId: UUID, username: String?, message: String) async throws {
        let chat = RaceChatMessage(
            id: nil,
            race_id: raceId,
            user_id: userId,
            username: username,
            message: message,
            created_at: nil
        )
        
        _ = try await client
            .from("Race_Chat")
            .insert(chat)
            .execute()
    }
    
    /// Subscribe to live chat messages for a race
    func subscribeToRaceChat(raceId: UUID) {
        chatChannel = client.channel("race_chat:\(raceId)")
        guard let channel = chatChannel else { return }
        
        Task {
            let stream = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "Race_Chat"
            )
            
            try await channel.subscribeWithError()
            
            for await change in stream {
                if let newMessage = try? JSONDecoder().decode(RaceChatMessage.self, from: JSONSerialization.data(withJSONObject: change.record)) {
                    DispatchQueue.main.async {
                        self.currentMessages.append(newMessage)
                    }
                }
            }
        }
    }
    
    /// Unsubscribe from chat and cleanup if no participants left
    func leaveRaceChat(raceId: UUID, userId: UUID) async {
        if let channel = chatChannel {
            await channel.unsubscribe()
            self.chatChannel = nil
        }
        
        // Check if there are remaining participants in the race
        do {
            let participants: [RaceParticipants] = try await client
                .from("Race_Participants")
                .select()
                .eq("race_id", value: raceId.uuidString)
                .execute()
                .value ?? []
            
            if participants.isEmpty {
                // Delete all chat messages for the race
                try await client
                    .from("Race_Chat")
                    .delete()
                    .eq("race_id", value: raceId.uuidString)
                    .execute()
                
                print("All chat messages for race \(raceId) deleted.")
            }
        } catch {
            print("Error checking participants or cleaning up chat: \(error)")
        }
    }
    
    /// Fetch past messages for a race
    func fetchMessages(raceId: UUID) async throws -> [RaceChatMessage] {
        let messages: [RaceChatMessage] = try await client
            .from("Race_Chat")
            .select()
            .eq("race_id", value: raceId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value ?? []
        
        DispatchQueue.main.async {
            self.currentMessages = messages
        }
        
        return messages
    }
    
    
    // MARK: - Global Leaderboard Management
    /// Fetch the top N users on the global leaderboard
    func fetchGlobalLeaderboard(top n: Int = 10) async throws -> [GlobalLeaderboardEntry] {
        let leaderboard: [GlobalLeaderboardEntry] = try await client
            .from("Global_Leaderboard")
            .select()
            .order("total_races_completed", ascending: false)
            .limit(n)
            .execute()
            .value ?? []
        return leaderboard
    }
    
    /// Update the leaderboard after a race finishes
    func updateGlobalLeaderboard(userId: UUID, distance: Double, finishedInTopThree: Bool) async throws {
        // Check if user already has an entry
        let entries: [GlobalLeaderboardEntry] = try await client
            .from("Global_Leaderboard")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value ?? []
        
        if var entry = entries.first {
            // Update existing entry
            let newRaces = (entry.total_races_completed ?? 0) + 1
            let newDistance = (entry.total_distance_covered ?? 0) + distance
            let newTopThree = (entry.top_three_finishes ?? 0) + (finishedInTopThree ? 1 : 0)
            
            _ = try await client
                .from("Global_Leaderboard")
                .update([
                    "total_races_completed": newRaces,
                    "total_distance_covered": newDistance,
                    "top_three_finishes": Double(newTopThree)
                ])
                .eq("user_id", value: userId.uuidString)
                .execute()
            
        } else {
            let rowData = GlobalLeaderboardEntry(
                id: nil,
                user_id: userId,
                total_races_completed: 1,
                total_distance_covered: distance,
                top_three_finishes: finishedInTopThree ? 1 : 0
            )
            
            // Insert new entry
            _ = try await client
                .from("Global_Leaderboard")
                .insert(rowData)
                .execute()
        }
    }
    
    /// Fetch the current user's leaderboard stats
    func fetchMyLeaderboardStats() async throws -> GlobalLeaderboardEntry? {
        guard let userId = self.currentUserId else { return nil }
        let entries: [GlobalLeaderboardEntry] = try await client
            .from("Global_Leaderboard")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value ?? []
        return entries.first
    }
}
