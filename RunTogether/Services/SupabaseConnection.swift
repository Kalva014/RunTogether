//
//  SupabaseConnection.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/19/25.
//

import Supabase
import SwiftUI

/// Connects to DB for authentication and multiplayer
@MainActor
class SupabaseConnection: ObservableObject {
    // MARK: - Initialization
    let client: SupabaseClient
    
    @Published var currentUserId: UUID?
    @Published var currentChannel: RealtimeChannelV2?
    @Published var currentRaceChannelId: UUID?
    @Published var isAuthenticated: Bool = false
    
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
        
        // Check for existing session on initialization
        Task {
            await checkAuthenticationState()
        }
    }
    
    // MARK: - Authentication State Management
    func checkAuthenticationState() async {
        do {
            let session = try await client.auth.session
            // session.user is non-optional, so access it directly.
            let user = session.user
            self.currentUserId = user.id
            self.isAuthenticated = true
            print("User session restored: \(user.email ?? "unknown")")
        } catch {
            // No valid session found.
            self.currentUserId = nil
            self.isAuthenticated = false
            print("No valid session found")
        }
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
        
        do {
            
            let res = try await self.client
                .from("Profiles")
                .insert(newRowData)
                .execute()
            
            print("Profile was created with the following status code: \(res.status)")
        } catch {
            print("Error creating profile: \(error)")
        }
    }
    
    func updateProfile(username: String? = nil, firstName: String? = nil, lastName: String? = nil, location: String? = nil, profilePictureUrl: String? = nil) async throws {
        guard let userId = self.currentUserId else { return }
        
        var updatesDict: [String: AnyJSON] = [:]
        if let username = username, !username.isEmpty { updatesDict["username"] = .string(username) }
        if let firstName = firstName, !firstName.isEmpty { updatesDict["first_name"] = .string(firstName) }
        if let lastName = lastName, !lastName.isEmpty { updatesDict["last_name"] = .string(lastName) }
        if let location = location, !location.isEmpty { updatesDict["location"] = .string(location) }
        if let profilePictureUrl = profilePictureUrl { updatesDict["profile_picture_url"] = .string(profilePictureUrl) }
        
        guard !updatesDict.isEmpty else { return }
                
        do {
            try await self.client
                .from("Profiles")
                .update(updatesDict)
                .eq("id", value: userId.uuidString)
                .execute()
        }
        catch {
            print("error: \(error)")
        }
    }
    
    func getProfile() async throws -> Profile? {
        guard let userId = self.currentUserId else { return nil }
        
        do {
            
            let response: PostgrestResponse<Profile> = try await self.client
                .from("Profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
            
            return response.value
        }
        catch {
            print("Error: \(error)")
            return nil
        }
    }
    
    // MARK: - Profile Picture Management
    /// Uploads a profile picture image to Supabase storage
    func uploadProfilePicture(imageData: Data) async throws -> String? {
        guard let userId = self.currentUserId else { return nil }
        
        do {
            let fileName = "\(userId.uuidString)/profile_picture_\(UUID().uuidString).jpg"
            
            // Upload to Supabase storage bucket (assuming bucket name is "profile-pictures")
            // Note: The bucket "profile-pictures" must be created in Supabase dashboard
            // and configured with appropriate policies for public read access
            try await client.storage
                .from("profile-pictures")
                .upload(
                    fileName,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )
            
            // Get public URL
            let url = try client.storage
                .from("profile-pictures")
                .getPublicURL(path: fileName)
            
            return url.absoluteString
        } catch {
            print("Error uploading profile picture: \(error)")
            throw error
        }
    }
    
    /// Deletes a profile picture from Supabase storage
    func deleteProfilePicture(fileName: String) async throws {
        guard let userId = self.currentUserId else { return }
        
        do {
            // Extract just the filename from the full URL if needed
            let path = fileName.contains(userId.uuidString) ? fileName : "\(userId.uuidString)/\(fileName)"
            
            try await client.storage
                .from("profile-pictures")
                .remove(paths: [path])
        } catch {
            print("Error deleting profile picture: \(error)")
            throw error
        }
    }
    
    /// Fetch profile for a specific user id
    func getProfileById(userId: UUID) async throws -> Profile? {
        guard let _ = self.currentUserId else { return nil }
        
        do {
            let response: PostgrestResponse<Profile> = try await self.client
                .from("Profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
            
            return response.value
        }
        catch {
            print("Error: \(error)")
            return nil
        }
    }
    
    /// Fetch profile for a specific username
    func getProfileByUsername(username: String) async throws -> Profile? {
        guard let _ = self.currentUserId else { return nil }
        
        do {
            let response: PostgrestResponse<Profile> = try await self.client
                .from("Profiles")
                .select()
                .eq("username", value: username)
                .single()
                .execute()
            
            return response.value
        }
        catch {
            print("Error: \(error)")
            return nil
        }
    }
    
    // MARK: - Authentication
    func signUp(email: String, password: String, username: String) async throws -> User {
        do {
            let response = try await self.client.auth.signUp(
                email: email,
                password: password,
                data: ["username": AnyJSON(username)]
            )
            self.currentUserId = response.user.id
            self.isAuthenticated = true
            return response.user
        }
        catch {
            print("Could not sign up: \(error)")
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws -> User {
        do {
            let response = try await self.client.auth.signIn(email: email, password: password)
            self.currentUserId = response.user.id
            self.isAuthenticated = true
            return response.user
        }
        catch {
            print("Could not sign in: \(error)")
            throw error
        }
    }
    
    func signOut() async throws {
        do {
            try await self.client.auth.signOut()
            self.currentUserId = nil
            self.isAuthenticated = false
        }
        catch {
            print("Could not sign out: \(error)")
            throw error
        }
    }
    
    // MARK: - Multiplayer Methods
    // CREATE RACE
    func createRace(name: String? = nil, mode: String, start_time: Date, distance: Double, useMiles: Bool) async throws -> Race? {
        do {
            guard let userId = self.currentUserId else {
                throw NSError(domain: "SupabaseConnection", code: 401,
                              userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
            }
            
            let brandNewRace = Race(id: nil, name: name, mode: mode, start_time: start_time, end_time: nil, distance: distance, use_miles: useMiles)
            
            // Decode as array, then get first
            let newRaces: [Race] = try await client
                .from("Races")
                .insert(brandNewRace)
                .select()
                .execute()
                .value
            
            guard let newRace = newRaces.first else {
                throw NSError(domain: "SupabaseConnection", code: 500,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to create race"])
            }
            
            let participant = RaceParticipants(
                id: nil,
                created_at: Date(),
                user_id: userId,
                finish_time: nil,
                distance_covered: 0.0,
                place: nil,
                average_pace: nil,
                race_id: newRace.id!
            )
            
            _ = try await client
                .from("Race_Participants")
                .insert(participant)
                .execute()
            
            return newRace
        }
        catch {
            print("Error creating a new race \(error)")
            return nil
        }
    }

    
    func leaveRace() async {
        await unsubscribeFromRaceBroadcasts()
        await unsubscribeFromChatBroadcasts()
    }
    
    func joinRaceWithCap(raceId: UUID, maxParticipants: Int) async throws -> UUID? {
        guard let userId = self.currentUserId else {
            throw NSError(domain: "SupabaseConnection", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        do {
            // 1️⃣ Check if the user is already in this race
            let existingParticipants: [RaceParticipants] = try await client
                .from("Race_Participants")
                .select()
                .eq("race_id", value: raceId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            
            if let _ = existingParticipants.first {
                print("User \(userId) is already in race \(raceId)")
                return raceId // Skip creating another participant
            }
            
            // 2️⃣ Check current number of participants
            let currNumParticipants = try await client
                .from("Race_Participants")
                .select("race_id", head: true, count: CountOption.exact)
                .eq("race_id", value: raceId.uuidString)
                .execute()
                .count
            
            guard let currNum = currNumParticipants, currNum < maxParticipants else {
                print("Race full")
                return nil
            }
            
            // 3️⃣ Create a new participant
            let participant = RaceParticipants(
                id: nil,
                created_at: Date(),
                user_id: userId,
                finish_time: nil,
                distance_covered: 0.0,
                place: nil,
                average_pace: nil,
                race_id: raceId
            )
            
            _ = try await client
                .from("Race_Participants")
                .insert(participant)
                .execute()
            
            print("Joined race \(raceId)")
            return raceId
        }
        catch {
            print("Error joining race: \(error)")
            return nil
        }
    }
    
    func joinRandomRace(mode: String, start_time: Date, maxParticipants: Int, distance: Double, useMiles: Bool) async throws -> UUID? {
        do {
            // Fetch open races matching the mode and distance
            let races: [Race] = try await self.client
                .from("Races")
                .select()
                .eq("mode", value: mode)
                .eq("distance", value: distance)
                .is("end_time", value: nil)
                .execute()
                .value
            
            // Try to join an existing race that isn't full and isn't too far progressed
            for race in races.shuffled() {
                guard let raceId = race.id else { continue }
                
                // Check if race is still joinable (not too far progressed)
                let raceAge = Date().timeIntervalSince(race.start_time)
                let maxJoinableAge: TimeInterval = 300 // 5 minutes - adjust as needed
                
                if raceAge > maxJoinableAge {
                    print("⚠️ Race \(raceId) is too far progressed (\(raceAge)s old), skipping")
                    continue
                }
                
                do {
                    let joinedId = try await joinRaceWithCap(raceId: raceId, maxParticipants: maxParticipants)
                    print("✅ Joined race \(raceId) with distance \(distance)m (age: \(raceAge)s)")
                    return joinedId
                } catch {
                    print("⚠️ Could not join race \(raceId): \(error)")
                    continue
                }
            }
            
            // If no suitable race found, create a new one
            print("ℹ️ No open race found for distance \(distance)m — creating a new one.")
            let newRace = try await createRace(mode: mode, start_time: start_time, distance: distance, useMiles: useMiles)
            return newRace?.id
        }
        catch {
            print("❌ Error joining random race: \(error)")
            throw error
        }
    }
    
    func getRaceDetails(raceId: UUID) async throws -> Race {
        do {
            return try await self.client
                .from("Races")
                .select()
                .eq("id", value: raceId)
                .single() // 👈 ensures only one result is returned
                .execute()
                .value
        }
        catch {
            print("Error getting race details: \(error)")
            throw error
        }
    }
    
    func getUpcomingRaces(limit: Int = 5) async throws -> [Race] {
        do {
            let now = Date()
            
            return try await self.client
                .from("Races")
                .select()
                .gt("start_time", value: now)     // 👈 Only races that haven’t started yet
                .order("start_time", ascending: true) // 👈 Soonest races first
                .limit(limit)                     // 👈 Limit to latest 5
                .execute()
                .value
        } catch {
            print("Error fetching upcoming races: \(error)")
            throw error
        }
    }
    
    /// Removes the current user from a specific race
    func leaveRace(raceId: UUID) async throws {
        guard let userId = self.currentUserId else {
            throw NSError(domain: "SupabaseConnection", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        do {
            print("🚪 Leaving race \(raceId) for user \(userId)")
            
            // Delete only this user's participant record
            _ = try await client
                .from("Race_Participants")
                .delete()
                .eq("race_id", value: raceId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            print("✅ User \(userId) removed from Race_Participants for race \(raceId)")
        }
        catch {
            print("❌ Error leaving race: \(error)")
            throw error
        }
    }
    
    /// Cancels the race (used by the creator) — deletes race + all participants
    func cancelRace(raceId: UUID) async throws {
        do {
            print("🗑️ Cancelling race \(raceId) — deleting race and all participants...")
            
            // First delete participants
            _ = try await client
                .from("Race_Participants")
                .delete()
                .eq("race_id", value: raceId.uuidString)
                .execute()
            
            // Then delete the race itself
            _ = try await client
                .from("Races")
                .delete()
                .eq("id", value: raceId.uuidString)
                .execute()
            
            print("✅ Successfully deleted race \(raceId) and all its participants")
        }
        catch {
            print("❌ Error cancelling race: \(error)")
            throw error
        }
    }
    
    // MARK: - Race Updates
    /// Broadcasts a low-latency update to other participants.
    func broadcastRaceUpdate(raceId: UUID, distance: Double, pace: Double, speed: Double) async {
       guard let userId = self.currentUserId else { return }
       
       do {
           let channel = try await getRaceChannel(raceId: raceId)
           
           await channel.broadcast(
               event: "update",
               message: [
                "user_id": .string(userId.uuidString),
                   "distance": .double(distance),
                   "pace": .double(pace),
                   "speed": .double(speed),
                   "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
               ]
           )
       } catch {
           print("Error broadcasting race update: \(error)")
       }
    }
       
   /// Sends a durable update to the Race_Updates table for history or stats.
   func persistRaceUpdate(raceId: UUID, distance: Double, pace: Double) async throws {
       guard let userId = self.currentUserId else { return }
       
       let update = RaceUpdates(
           id: nil,
           created_at: Date(),
           race_id: raceId,
           user_id: userId,
           current_distance: distance,
           current_pace: pace
       )
       
       do {
           _ = try await self.client
               .from("Race_Updates")
               .insert(update)
               .execute()
       } catch {
           print("Error persisting race update: \(error)")
           throw error
       }
   }
   
//   /// Subscribes to low-latency broadcast updates for the current race.
//   func subscribeToRaceBroadcasts(raceId: UUID) async {
//       do {
//           let channel = try await getRaceChannel(raceId: raceId)
//           self.currentChannel = channel
//           
//           // Listen for broadcast events
//           let stream = await channel.broadcastStream(event: "update")
//           
//           try await channel.subscribeWithError()
//           print("✅ Subscribed to race broadcasts for \(raceId)")
//           
//           for await message in stream {
//               // message is a JSONObject ([String: AnyJSON])
//               let userId = message["user_id"]?.stringValue ?? "unknown"
//               let distance = message["distance"]?.doubleValue ?? 0
//               let pace = message["pace"]?.doubleValue ?? 0
//               let timestamp = message["timestamp"]?.stringValue ?? ""
//               
//               print("📡 Live update → user: \(userId), distance: \(distance), pace: \(pace), at \(timestamp)")
//               
//               // TODO: push to your UI state
//           }
//           
//       } catch {
//           print("Error subscribing to race broadcasts: \(error)")
//       }
//   }
    
    /// Subscribes to low-latency broadcast updates for the current race.
    func subscribeToRaceBroadcasts(raceId: UUID) async {
        do {
            if let activeRaceId = currentRaceChannelId, activeRaceId != raceId {
                print("🔄 Switching race channel from \(activeRaceId) to \(raceId)")
                await unsubscribeFromRaceBroadcasts()
            }
            
            let channel = try await getRaceChannel(raceId: raceId)
            
            // Subscribe to the channel first
            try await channel.subscribeWithError()
            currentChannel = channel
            currentRaceChannelId = raceId
            print("✅ Subscribed to race broadcasts for \(raceId)")
            
            // Note: The stream processing should happen in the scene
            // where it can access MainActor context properly
            
        } catch {
            print("Error subscribing to race broadcasts: \(error)")
        }
    }
   
   /// Closes the broadcast channel cleanly when the race ends.
   func unsubscribeFromRaceBroadcasts() async {
       guard let channel = currentChannel else {
           currentRaceChannelId = nil
           return
       }
       await channel.unsubscribe()
       currentChannel = nil // Clear the channel reference
       currentRaceChannelId = nil
       print("🛑 Unsubscribed from race broadcasts")
   }
   
   /// Reuses or creates a broadcast channel for the race.
   private func getRaceChannel(raceId: UUID) async throws -> RealtimeChannelV2 {
       if let channel = currentChannel, currentRaceChannelId == raceId {
           return channel
       }
       
       if let existingChannel = currentChannel {
           await existingChannel.unsubscribe()
       }
       
       let channel = client.channel("race:\(raceId)") {
           $0.broadcast.acknowledgeBroadcasts = true
       }
       
       self.currentChannel = channel
       self.currentRaceChannelId = raceId
       return channel
   }

    
    // MARK: - Race Completion
    func checkIfRaceFinished(raceId: UUID) async throws {
        do {
            let participants: [RaceParticipants] = try await self.client
                .from("Race_Participants")
                .select()
                .eq("race_id", value: raceId.uuidString)
                .execute()
                .value
            
            let allFinished = participants.allSatisfy { $0.finish_time != nil }
            
            if allFinished {
                // First, update the race end time
                try await self.client
                    .from("Races")
                    .update(["end_time": ISO8601DateFormatter().string(from: Date())])
                    .eq("id", value: raceId.uuidString)
                    .execute()
                
                // Cleanup race updates to reduce noise, but keep race + participant data
                try await self.client
                    .from("Race_Updates")
                    .delete()
                    .eq("race_id", value: raceId.uuidString)
                    .execute()
                
                print("Race \(raceId) finished — end_time set and live updates cleared (data retained for results).")
            }
        }
        catch {
            print("Error checking race finish: \(error)")
        }
    }
    
    func markParticipantDisconnected(raceId: UUID, userId: UUID) async throws {
        do {
            // Use current timestamp for disconnected users (they "finished" when they left)
            let rowData: [String: AnyJSON] = [
                "finish_time": AnyJSON.string(Date().ISO8601Format()),
                "distance_covered": AnyJSON.double(0.0),
                "average_pace": AnyJSON.double(0.0)
            ]
            
            _ = try await client
                .from("Race_Participants")
                .update(rowData)
                .eq("race_id", value: raceId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            print("User \(userId) disconnected, marked as finished with timestamp")
            try await checkIfRaceFinished(raceId: raceId)
        }
        catch {
            print("Error marking participant as finished: \(error)")
        }
    }
    
    func markParticipantFinished(raceId: UUID, distance: Double, pace: Double, finishPlace: Int) async throws {
        guard let userId = self.currentUserId else { return }
        
        do {
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
        catch {
            print("Error marking participant finished: \(error)")
        }
    }
    
    
    // MARK: - Friend Management

    /// Adds a friend by their username
    func addFriend(username: String) async throws {
        guard let userId = self.currentUserId else { return }

        do {
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
                .or("and(user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(friend.id.uuidString)),and(user_id_1.eq.\(friend.id.uuidString),user_id_2.eq.\(userId.uuidString))")
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
        catch {
            print("Error adding friend: \(error)")
        }
    }

    /// Removes a friend by their username
    func removeFriend(username: String) async throws {
        guard let userId = self.currentUserId else { return }

        do {
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
                .or("and(user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(friend.id.uuidString)),and(user_id_1.eq.\(friend.id.uuidString),user_id_2.eq.\(userId.uuidString))")
                .execute()

            print("Friend removed: \(username)")
        }
        catch {
            print("Error removing friend: \(error)")
        }
    }

    /// Lists all friends for the current user
    func listFriends() async throws -> [String] {
        let profiles = try await fetchFriendProfiles()
        return profiles.map { $0.username }
    }
    
    /// Fetches the full profile records for all of the current user's friends
    func fetchFriendProfiles() async throws -> [Profile] {
        guard let userId = self.currentUserId else { return [] }
        
        do {
            let friends: [Friend] = try await client
                .from("Friends")
                .select()
                .or("user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(userId.uuidString)")
                .execute()
                .value ?? []
            
            var friendIds = Set<UUID>()
            
            for f in friends {
                if f.user_id_1 != userId { friendIds.insert(f.user_id_1) }
                if f.user_id_2 != userId { friendIds.insert(f.user_id_2) }
            }
            
            guard !friendIds.isEmpty else { return [] }
            
            let profiles: [Profile] = try await client
                .from("Profiles")
                .select()
                .in("id", values: friendIds.map { $0.uuidString })
                .execute()
                .value ?? []
            
            return profiles
        }
        catch {
            if error.isCancelledRequest {
                print("⚠️ fetchFriendProfiles cancelled")
                return []
            } else {
                print("Error fetching friend profiles: \(error)")
                return []
            }
        }
    }
    
    /// Fetches active races (if any) for the supplied user ids
    func fetchActiveRaces(for userIds: [UUID]) async throws -> [UUID: UUID] {
        guard !userIds.isEmpty else { return [:] }
        
        do {
            let participants: [RaceParticipants] = try await client
                .from("Race_Participants")
                .select()
                .in("user_id", values: userIds.map { $0.uuidString })
                .is("finish_time", value: nil)
                .execute()
                .value ?? []
            
            var mapping: [UUID: UUID] = [:]
            for participant in participants {
                mapping[participant.user_id] = participant.race_id
            }
            return mapping
        }
        catch {
            if error.isCancelledRequest {
                print("⚠️ fetchActiveRaces cancelled")
                return [:]
            } else {
                print("Error fetching active races: \(error)")
                return [:]
            }
        }
    }
    
    // Checks if user is in a race or not
    func getActiveRaceForUser(userId: UUID) async throws -> UUID? {
        do {
            let results: [RaceParticipants] = try await client
                .from("Race_Participants")
                .select("*") // ✅ select all fields
                .eq("user_id", value: userId.uuidString)
                .is("finish_time", value: nil)
                .limit(1)
                .execute()
                .value

            return results.first?.race_id
        } catch {
            print("❌ Error fetching active race for user \(userId): \(error)")
            return nil
        }
    }


    // MARK: - Run Club Management
    /// Create a new run club
    func createRunClub(name: String, description: String? = nil) async throws {
        guard let userId = self.currentUserId else { return }

        do {
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
                    "owner": userId.uuidString,
                    "description": description
                ])
                .execute()
            
            print("Run club \(name) created!")
            
            try await self.joinRunClub(name: name)
        }
        catch {
            print("Error creating run club: \(error)")
        }
    }

    /// Join a run club by name
    func joinRunClub(name: String) async throws {
        guard let userId = self.currentUserId else { return }

        do {
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
        catch {
            print("Error joining run club: \(error)")
        }
    }

    /// Leave a run club by name
    func leaveRunClub(name: String) async throws {
        guard let userId = self.currentUserId else { return }

        do {
            _ = try await client
                .from("Run_Club_Members")
                .delete()
                .eq("group_id", value: name)
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            print("Left run club \(name)")
        }
        catch {
            print("Error leaving run club: \(error)")
        }
    }

    /// List all members of a run club
    func listRunClubMembers(name: String) async throws -> [String] {
        do {
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
        catch {
            print("Error listing run club members: \(error)")
            return []
        }
    }

    /// List all run clubs the current user belongs to
    func listMyRunClubs() async throws -> [String] {
        guard let userId = self.currentUserId else {
            print("❌ No current user ID")
            return []
        }

        do {
            let memberships: [RunClubMember] = try await client
                .from("Run_Club_Members")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value ?? []
            
            print("✅ Found \(memberships.count) memberships for user \(userId)")
            return memberships.map { $0.group_id }
        }
        catch {
            if error.isCancelledRequest {
                print("⚠️ listMyRunClubs request cancelled")
                return []
            } else {
                print("❌ Error listing run clubs: \(error)")
                throw error
            }
        }
    }
    
    /// Fetch all run clubs
    func listRunClubs() async throws -> [RunClub] {
        do {
            let clubs: [RunClub] = try await client
                .from("Run_Clubs")
                .select()
                .execute()
                .value ?? []
            
            return clubs
        }
        catch {
            print("Error listing run clubs: \(error)")
            return []
        }
    }
    
    /// Fetch specific run clubs by name
    func fetchRunClubs(named clubNames: [String]) async throws -> [RunClub] {
        guard !clubNames.isEmpty else { return [] }
        
        do {
            let clubs: [RunClub] = try await client
                .from("Run_Clubs")
                .select()
                .in("name", values: clubNames)
                .execute()
                .value ?? []
            
            return clubs
        }
        catch {
            print("Error fetching run clubs by name: \(error)")
            throw error
        }
    }
    
    /// Fetch specific run clubs a user is a part of
    func listSpecificUserRunClubs(specificId: UUID) async throws -> [String] {
        guard let _ = self.currentUserId else { return [] }

        do {
            let memberships: [RunClubMember] = try await client
                .from("Run_Club_Members")
                .select()
                .eq("user_id", value: specificId.uuidString)
                .execute()
                .value ?? []
            
            return memberships.map { $0.group_id }
        }
        catch {
            print("Error listing run clubs: \(error)")
            return []
        }
    }
    
    /// Delete a run club (only if the current user is the owner)
    func deleteRunClub(name: String) async throws {
        guard let userId = self.currentUserId else { return }

        do {
            // Fetch the run club to check ownership
            let clubs: [RunClub] = try await client
                .from("Run_Clubs")
                .select()
                .eq("name", value: name)
                .execute()
                .value ?? []
            
            guard let club = clubs.first else {
                print("Run club \(name) not found")
                return
            }
            
            // Verify current user is the owner
            guard club.owner == userId else {
                print("User is not the owner of run club \(name)")
                return
            }
            
            // Optionally delete memberships first (if your schema does not cascade automatically)
            _ = try await client
                .from("Run_Club_Members")
                .delete()
                .eq("group_id", value: name)
                .execute()
            
            // Delete the run club
            _ = try await client
                .from("Run_Clubs")
                .delete()
                .eq("name", value: name)
                .execute()
            
            print("Run club \(name) deleted by owner")
        }
        catch {
            print("Error deleting run club \(name): \(error)")
        }
    }

    // MARK: - Live Post Race Chat
    var chatChannel: RealtimeChannelV2?
    // Track which raceId the chatChannel is for
    private(set) var currentChatRaceId: UUID?

    /// Broadcasts a chat message to all participants (low-latency)
    func broadcastChatMessage(raceId: UUID, message: String, username: String) async {
        guard let userId = self.currentUserId else { return }
        
        do {
            let channel = try await getChatChannel(raceId: raceId)
            
            await channel.broadcast(
                event: "chat_message",
                message: [
                    "user_id": .string(userId.uuidString),
                    "username": .string(username),
                    "message": .string(message),
                    "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
                ]
            )
        } catch {
            print("Error broadcasting chat message: \(error)")
        }
    }
    
    /// Subscribes to chat broadcasts for a race
    func subscribeToChatBroadcasts(raceId: UUID) async {
        do {
            if let currentId = currentChatRaceId, currentId != raceId {
                if let channel = chatChannel {
                    print("🛑 Unsubscribing old chat channel for raceId: \(currentId)")
                    await channel.unsubscribe()
                }
                chatChannel = nil
            }
            let channel = try await getChatChannel(raceId: raceId)
            currentChatRaceId = raceId
            self.chatChannel = channel
            try await channel.subscribeWithError()
            print("✅ Subscribed to chat broadcasts for raceId: \(raceId)")
        } catch {
            print("Error subscribing to chat broadcasts: \(error)")
        }
    }
    
    /// Unsubscribe from chat broadcasts
    func unsubscribeFromChatBroadcasts() async {
        if let channel = chatChannel {
            print("🛑 Unsubscribing chatChannel for raceId: \(currentChatRaceId?.uuidString ?? "nil")")
            await channel.unsubscribe()
        }
        chatChannel = nil
        currentChatRaceId = nil
    }
    
    /// Reuses or creates a broadcast channel for chat
    private func getChatChannel(raceId: UUID) async throws -> RealtimeChannelV2 {
        if let channel = chatChannel, currentChatRaceId == raceId {
            print("♻️ Re-using chatChannel for raceId: \(raceId)")
            return channel
        }
        if let channel = chatChannel, currentChatRaceId != raceId {
            print("🛑 Closing previous chatChannel for raceId: \(currentChatRaceId?.uuidString ?? "nil")")
            await channel.unsubscribe()
            chatChannel = nil
            currentChatRaceId = nil
        }
        print("🔄 Creating new chatChannel for raceId: \(raceId)")
        let channel = client.channel("race_chat:\(raceId)") {
            $0.broadcast.acknowledgeBroadcasts = true
        }
        chatChannel = channel
        currentChatRaceId = raceId
        return channel
    }
    
    
    // MARK: - Ranked System Management
    
    /// Get or create ranked profile for current user
    func getRankedProfile() async throws -> RankedProfile? {
        guard let userId = self.currentUserId else { return nil }
        
        do {
            // Try to fetch existing ranked profile
            let profiles: [RankedProfile] = try await client
                .from("Ranked_Profiles")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value ?? []
            
            if let profile = profiles.first {
                return profile
            } else {
                // Create new ranked profile if doesn't exist
                return try await createRankedProfile(userId: userId)
            }
        } catch {
            if error.isCancelledRequest {
                print("⚠️ getRankedProfile cancelled")
                return nil
            } else {
                print("Error fetching ranked profile: \(error)")
                throw error
            }
        }
    }
    
    /// Get ranked profile for a specific user
    func getRankedProfile(userId: UUID) async throws -> RankedProfile? {
        do {
            let profiles: [RankedProfile] = try await client
                .from("Ranked_Profiles")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value ?? []
            
            if let profile = profiles.first {
                return profile
            } else {
                // Create new ranked profile if doesn't exist
                return try await createRankedProfile(userId: userId)
            }
        } catch {
            if error.isCancelledRequest {
                print("⚠️ getRankedProfile(\(userId)) cancelled")
                return nil
            } else {
                print("Error fetching ranked profile for user \(userId): \(error)")
                throw error
            }
        }
    }
    
    /// Create a new ranked profile for a user (starts at Bronze IV, 0 LP)
    private func createRankedProfile(userId: UUID) async throws -> RankedProfile {
        let newProfile = RankedProfile.newProfile(userId: userId)
        
        do {
            let created: [RankedProfile] = try await client
                .from("Ranked_Profiles")
                .insert(newProfile)
                .select()
                .execute()
                .value ?? []
            
            print("✅ Created new ranked profile for user \(userId): Bronze IV - 0 LP")
            return created.first ?? newProfile
        } catch {
            print("Error creating ranked profile: \(error)")
            throw error
        }
    }
    
    /// Fetch ranked profiles for a batch of user IDs
    func fetchRankedProfiles(for userIds: [UUID]) async throws -> [UUID: RankedProfile] {
        guard !userIds.isEmpty else { return [:] }
        
        do {
            let idStrings = userIds.map { $0.uuidString }
            let profiles: [RankedProfile] = try await client
                .from("Ranked_Profiles")
                .select()
                .in("user_id", values: idStrings)
                .execute()
                .value ?? []
            
            var map: [UUID: RankedProfile] = [:]
            for profile in profiles {
                map[profile.user_id] = profile
            }
            return map
        } catch {
            print("Error fetching ranked profiles batch: \(error)")
            throw error
        }
    }
    
    /// Update ranked profile after a race completes
    /// - Parameters:
    ///   - userId: User ID to update
    ///   - place: Finishing position in the race
    ///   - totalRunners: Total number of runners in the race
    /// - Returns: LPChangeResult showing the rank change details
    func updateRankAfterRace(userId: UUID, place: Int, totalRunners: Int) async throws -> LPChangeResult {
        do {
            // Get current ranked profile
            guard let profile = try await getRankedProfile(userId: userId) else {
                throw NSError(domain: "SupabaseConnection", code: 404,
                              userInfo: [NSLocalizedDescriptionKey: "Ranked profile not found"])
            }
            
            let oldRank = profile.displayString
            
            // Calculate LP change
            let lpChange = LPCalculator.calculateLPChange(place: place, totalRunners: totalRunners)
            
            // Apply LP change and handle promotion/demotion
            let updatedProfile = LPCalculator.applyLPChange(to: profile, lpChange: lpChange)
            
            let newRank = updatedProfile.displayString
            let promoted = updatedProfile.tier.numericValue > profile.tier.numericValue ||
                          (updatedProfile.tier == profile.tier && 
                           (updatedProfile.division?.rawValue ?? 0) < (profile.division?.rawValue ?? 0))
            let demoted = updatedProfile.tier.numericValue < profile.tier.numericValue ||
                         (updatedProfile.tier == profile.tier && 
                          (updatedProfile.division?.rawValue ?? 0) > (profile.division?.rawValue ?? 0))
            
            // Increment total races
            let currentTotalRaces = profile.total_races ?? 0
            let newTotalRaces = currentTotalRaces + 1
            
            // Increment top 3 finishes if applicable
            let currentTop3 = profile.top_3_finishes ?? 0
            let newTop3 = place <= 3 ? currentTop3 + 1 : currentTop3
            
            // Update in database
            let updates: [String: AnyJSON] = [
                "rank_tier": .string(updatedProfile.rank_tier),
                "rank_division": updatedProfile.rank_division != nil ? .integer(updatedProfile.rank_division!) : .null,
                "league_points": .integer(updatedProfile.league_points),
                "top_3_finishes": .integer(newTop3),
                "total_races": .integer(newTotalRaces),
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            _ = try await client
                .from("Ranked_Profiles")
                .update(updates)
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            print("✅ Updated rank for user \(userId): \(oldRank) → \(newRank) (\(lpChange > 0 ? "+" : "")\(lpChange) LP)")
            
            return LPChangeResult(
                oldRank: oldRank,
                newRank: newRank,
                lpChange: lpChange,
                promoted: promoted,
                demoted: demoted,
                newLP: updatedProfile.league_points,
                oldLP: profile.league_points,
                tier: updatedProfile.tier,
                division: updatedProfile.division
            )
        } catch {
            print("Error updating rank after race: \(error)")
            throw error
        }
    }
    
    /// Increment ranked wins for a user
    /// Fetch ranked leaderboard (sorted by rank tier, division, and LP)
    /// - Parameters:
    ///   - page: Page number for pagination
    ///   - pageSize: Number of entries per page
    /// - Returns: Array of ranked leaderboard entries
    func fetchRankedLeaderboard(page: Int = 0, pageSize: Int = 10) async throws -> [RankedLeaderboardEntry] {
        do {
            let offset = page * pageSize
            
            // Fetch all profiles and sort in Swift (Supabase can't sort by multiple custom fields easily)
            let allProfiles: [RankedProfile] = try await client
                .from("Ranked_Profiles")
                .select()
                .execute()
                .value ?? []
            
            // Sort by rank tier (desc), division (asc), LP (desc)
            let sortedProfiles = allProfiles.sorted { p1, p2 in
                // Compare tier first (higher tier = better)
                if p1.tier.numericValue != p2.tier.numericValue {
                    return p1.tier.numericValue > p2.tier.numericValue
                }
                
                // If same tier, compare division (lower division number = better, e.g., I < IV)
                if p1.tier != .champion {
                    let div1 = p1.division?.rawValue ?? 99
                    let div2 = p2.division?.rawValue ?? 99
                    if div1 != div2 {
                        return div1 < div2
                    }
                }
                
                // If same division, compare LP (higher LP = better)
                return p1.league_points > p2.league_points
            }
            
            // Paginate
            let start = offset
            let end = min(offset + pageSize, sortedProfiles.count)
            let paginatedProfiles = Array(sortedProfiles[start..<end])
            
            // Convert to leaderboard entries
            let entries = paginatedProfiles.map { profile in
                RankedLeaderboardEntry(
                    id: profile.id,
                    user_id: profile.user_id,
                    rank_tier: profile.rank_tier,
                    rank_division: profile.rank_division,
                    league_points: profile.league_points,
                    top_3_finishes: profile.top_3_finishes,
                    total_races: profile.total_races
                )
            }
            
            return entries
        } catch {
            print("Error fetching ranked leaderboard: \(error)")
            throw error
        }
    }
    
    /// Fetch ranked leaderboard for friends only
    func fetchFriendsRankedLeaderboard() async throws -> [RankedLeaderboardEntry] {
        guard let userId = self.currentUserId else { return [] }
        
        do {
            // Get friend IDs
            let friendProfiles = try await fetchFriendProfiles()
            let friendIds = friendProfiles.map { $0.id }
            
            guard !friendIds.isEmpty else { return [] }
            
            // Fetch ranked profiles for friends
            let profiles: [RankedProfile] = try await client
                .from("Ranked_Profiles")
                .select()
                .in("user_id", values: friendIds.map { $0.uuidString })
                .execute()
                .value ?? []
            
            // Also include current user
            if let myProfile = try await getRankedProfile() {
                var allProfiles = profiles
                if !allProfiles.contains(where: { $0.user_id == userId }) {
                    allProfiles.append(myProfile)
                }
                
                // Sort by rank
                let sortedProfiles = allProfiles.sorted { p1, p2 in
                    if p1.tier.numericValue != p2.tier.numericValue {
                        return p1.tier.numericValue > p2.tier.numericValue
                    }
                    if p1.tier != .champion {
                        let div1 = p1.division?.rawValue ?? 99
                        let div2 = p2.division?.rawValue ?? 99
                        if div1 != div2 {
                            return div1 < div2
                        }
                    }
                    return p1.league_points > p2.league_points
                }
                
                // Convert to leaderboard entries
                return sortedProfiles.map { profile in
                    RankedLeaderboardEntry(
                        id: profile.id,
                        user_id: profile.user_id,
                        rank_tier: profile.rank_tier,
                        rank_division: profile.rank_division,
                        league_points: profile.league_points,
                        top_3_finishes: profile.top_3_finishes,
                        total_races: profile.total_races
                    )
                }
            }
            
            return []
        } catch {
            print("Error fetching friends ranked leaderboard: \(error)")
            throw error
        }
    }
    
    /// Get current user's rank position on the global ranked leaderboard
    func getMyRankedPosition() async throws -> Int? {
        guard let userId = self.currentUserId else { return nil }
        
        do {
            guard try await getRankedProfile() != nil else { return nil }
            
            // Fetch all profiles
            let allProfiles: [RankedProfile] = try await client
                .from("Ranked_Profiles")
                .select()
                .execute()
                .value ?? []
            
            // Sort by rank
            let sortedProfiles = allProfiles.sorted { p1, p2 in
                if p1.tier.numericValue != p2.tier.numericValue {
                    return p1.tier.numericValue > p2.tier.numericValue
                }
                if p1.tier != .champion {
                    let div1 = p1.division?.rawValue ?? 99
                    let div2 = p2.division?.rawValue ?? 99
                    if div1 != div2 {
                        return div1 < div2
                    }
                }
                return p1.league_points > p2.league_points
            }
            
            // Find position
            if let position = sortedProfiles.firstIndex(where: { $0.user_id == userId }) {
                return position + 1 // 1-based ranking
            }
            
            return nil
        } catch {
            if error.isCancelledRequest {
                print("⚠️ getMyRankedPosition cancelled")
                return nil
            } else {
                print("Error getting ranked position: \(error)")
                throw error
            }
        }
    }
    
    /// Find available ranked races for matchmaking
    /// - Parameters:
    ///   - mode: Race mode
    ///   - distance: Race distance in meters
    ///   - useMiles: Whether to use miles
    ///   - maxSpread: Maximum tier spread for matchmaking (1 = ±1 tier, 2 = ±2 tiers)
    /// - Returns: Available race IDs that match the criteria
    func findRankedMatches(mode: String, distance: Double, useMiles: Bool, maxSpread: Int = 1) async throws -> [Race] {
        guard self.currentUserId != nil else { return [] }
        
        do {
            // Get user's ranked profile
            guard let myProfile = try await getRankedProfile() else { return [] }
            
            // Get acceptable tier range
            _ = RankMatchmaking.getTierRange(for: myProfile.tier, spread: maxSpread)
            
            // Fetch open races matching mode and distance
            let races: [Race] = try await client
                .from("Races")
                .select()
                .eq("mode", value: mode)
                .eq("distance", value: distance)
                .is("end_time", value: nil)
                .execute()
                .value ?? []
            
            // Filter races by checking participant ranks
            var suitableRaces: [Race] = []
            
            for race in races {
                guard let raceId = race.id else { continue }
                
                // Check if race is still joinable (not too far progressed)
                let raceAge = Date().timeIntervalSince(race.start_time)
                let maxJoinableAge: TimeInterval = 300 // 5 minutes
                
                if raceAge > maxJoinableAge {
                    continue
                }
                
                // Get participants of this race
                let participants: [RaceParticipants] = try await client
                    .from("Race_Participants")
                    .select()
                    .eq("race_id", value: raceId.uuidString)
                    .execute()
                    .value ?? []
                
                // Check if any participant has a compatible rank
                var isCompatible = true
                for participant in participants {
                    if let participantProfile = try? await getRankedProfile(userId: participant.user_id) {
                        if !RankMatchmaking.canMatch(tier1: myProfile.tier, tier2: participantProfile.tier, maxSpread: maxSpread) {
                            isCompatible = false
                            break
                        }
                    }
                }
                
                if isCompatible {
                    suitableRaces.append(race)
                }
            }
            
            return suitableRaces
        } catch {
            print("Error finding ranked matches: \(error)")
            throw error
        }
    }
    
    /// Create a ranked race
    func createRankedRace(name: String? = nil, mode: String, start_time: Date, distance: Double, useMiles: Bool) async throws -> Race? {
        // For now, ranked races use the same table as regular races
        // Just set mode to "ranked" to distinguish them
        return try await createRace(name: name, mode: "ranked", start_time: start_time, distance: distance, useMiles: useMiles)
    }
    
    /// Join a ranked race with matchmaking validation
    func joinRankedRace(raceId: UUID, maxParticipants: Int) async throws -> UUID? {
        guard self.currentUserId != nil else { return nil }
        
        do {
            // Get user's ranked profile
            guard let myProfile = try await getRankedProfile() else {
                throw NSError(domain: "SupabaseConnection", code: 404,
                              userInfo: [NSLocalizedDescriptionKey: "Ranked profile not found"])
            }
            
            // Get race participants
            let participants: [RaceParticipants] = try await client
                .from("Race_Participants")
                .select()
                .eq("race_id", value: raceId.uuidString)
                .execute()
                .value ?? []
            
            // Check rank compatibility
            for participant in participants {
                if let participantProfile = try? await getRankedProfile(userId: participant.user_id) {
                    if !RankMatchmaking.canMatch(tier1: myProfile.tier, tier2: participantProfile.tier, maxSpread: 2) {
                        print("❌ Rank mismatch: Cannot join race with participants of very different rank")
                        return nil
                    }
                }
            }
            
            // Join the race using existing method
            return try await joinRaceWithCap(raceId: raceId, maxParticipants: maxParticipants)
        } catch {
            print("Error joining ranked race: \(error)")
            throw error
        }
    }
    
    // MARK: - Global Leaderboard Management
    /// Fetch the top N users on the global leaderboard
    func fetchGlobalLeaderboard(page: Int = 0, pageSize: Int = 10) async throws -> [GlobalLeaderboardEntry] {
        do {
            let offset = page * pageSize
            
            let leaderboard: [GlobalLeaderboardEntry] = try await client
                .from("Global_Leaderboard")
                .select()
                .order("total_races_completed", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value ?? []
            return leaderboard
        }
        catch {
            print("Error fetching global leaderboard: \(error)")
            throw error
        }
    }
    
    /// Gets total number of users on the leaderboard
    func fetchGlobalLeaderboardCount() async throws -> Int {
        do {
            let response = try await client
                .from("Global_Leaderboard")
                .select("user_id", count: .exact)
                .execute()
            
            return response.count ?? 0
        }
        catch {
            print("Error fetching global leaderboard count: \(error)")
            throw error
        }
    }
    
    /// Fetch the current user's rank on the leaderboard
    /// - Returns: User's rank (1-based) or nil if not found
    func fetchMyLeaderboardRank() async throws -> Int? {
        guard let _ = self.currentUserId else { return nil }
        
        do {
            // Get user's total races
            let myStats = try await fetchMyLeaderboardStats()
            guard let myRaces = myStats?.total_races_completed else { return nil }
            
            // Count how many users have more races
            let response = try await client
                .from("Global_Leaderboard")
                .select("user_id", count: .exact)
                .gt("total_races_completed", value: myRaces)
                .execute()
            
            let rank = (response.count ?? 0) + 1
            return rank
        }
        catch {
            print("Error fetching my leaderboard rank: \(error)")
            throw error
        }
    }
    
    /// Update the leaderboard after a race finishes
    func updateGlobalLeaderboard(userId: UUID, distance: Double, finishedInTopThree: Bool) async throws {
        do {
            // Check if user already has an entry
            let entries: [GlobalLeaderboardEntry] = try await client
                .from("Global_Leaderboard")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value ?? []
            
            if let entry = entries.first {
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
        catch {
            print("Error updating global leaderboard: \(error)")
        }
    }
    
    /// Fetch the current user's leaderboard stats
    func fetchMyLeaderboardStats() async throws -> GlobalLeaderboardEntry? {
        guard let userId = self.currentUserId else { return nil }
        
        do {
            let entries: [GlobalLeaderboardEntry] = try await client
                .from("Global_Leaderboard")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value ?? []
            return entries.first
        }
        catch {
            print("Error fetching leaderboard stats: \(error)")
            return nil
        }
    }
    
    /// Fetch the current user's leaderboard stats
    func fetchSpecificUserLeaderboardStats(specificUserId: UUID) async throws -> GlobalLeaderboardEntry? {
        guard let _ = self.currentUserId else { return nil }
        
        do {
            let entries: [GlobalLeaderboardEntry] = try await client
                .from("Global_Leaderboard")
                .select()
                .eq("user_id", value: specificUserId.uuidString)
                .execute()
                .value ?? []
            return entries.first
        }
        catch {
            print("Error fetching leaderboard stats: \(error)")
            return nil
        }
    }
}
