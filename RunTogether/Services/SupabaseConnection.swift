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
                    path: fileName,
                    file: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg", upsert: true
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
        if let currentChannel = currentChannel {
            await currentChannel.unsubscribe()
            self.currentChannel = nil
        }
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
           
           try await channel.broadcast(
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
            let channel = try await getRaceChannel(raceId: raceId)
            self.currentChannel = channel
            
            // Subscribe to the channel first
            try await channel.subscribeWithError()
            print("✅ Subscribed to race broadcasts for \(raceId)")
            
            // Note: The stream processing should happen in the scene
            // where it can access MainActor context properly
            
        } catch {
            print("Error subscribing to race broadcasts: \(error)")
        }
    }
   
   /// Closes the broadcast channel cleanly when the race ends.
   func unsubscribeFromRaceBroadcasts() async {
       guard let channel = currentChannel else { return }
       do {
           try await channel.unsubscribe()
           print("🛑 Unsubscribed from race broadcasts")
       } catch {
           print("Error unsubscribing: \(error)")
       }
   }
   
   /// Reuses or creates a broadcast channel for the race.
   private func getRaceChannel(raceId: UUID) async throws -> RealtimeChannelV2 {
       if let channel = currentChannel {
           return channel
       }
       
       let channel = client.channel("race:\(raceId)") {
           $0.broadcast.acknowledgeBroadcasts = true
       }
       
       self.currentChannel = channel
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
        guard let userId = self.currentUserId else { return [] }
        
        do {
            let friends: [Friend] = try await client
               .from("Friends")
               .select()
               .or("user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(userId.uuidString)")
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
        catch {
            print("Error listing friends: \(error)")
            return []
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
            print("❌ Error listing run clubs: \(error)")
            throw error
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

    /// Broadcasts a chat message to all participants (low-latency)
    func broadcastChatMessage(raceId: UUID, message: String, username: String) async {
        guard let userId = self.currentUserId else { return }
        
        do {
            let channel = try await getChatChannel(raceId: raceId)
            
            try await channel.broadcast(
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
            let channel = try await getChatChannel(raceId: raceId)
            self.chatChannel = channel
            
            // Subscribe to the channel
            try await channel.subscribeWithError()
            print("✅ Subscribed to chat broadcasts for \(raceId)")
            
        } catch {
            print("Error subscribing to chat broadcasts: \(error)")
        }
    }
    
    /// Unsubscribe from chat broadcasts
    func unsubscribeFromChatBroadcasts() async {
        guard let channel = chatChannel else { return }
        do {
            try await channel.unsubscribe()
            self.chatChannel = nil
            print("🛑 Unsubscribed from chat broadcasts")
        } catch {
            print("Error unsubscribing from chat: \(error)")
        }
    }
    
    /// Reuses or creates a broadcast channel for chat
    private func getChatChannel(raceId: UUID) async throws -> RealtimeChannelV2 {
        if let channel = chatChannel {
            return channel
        }
        
        let channel = client.channel("race_chat:\(raceId)") {
            $0.broadcast.acknowledgeBroadcasts = true
        }
        
        self.chatChannel = channel
        return channel
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
