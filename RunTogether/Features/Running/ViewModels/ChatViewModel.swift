//
//  ChatViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 11/2/25.
//

import Foundation
import Combine

struct ChatMessage: Identifiable {
    let id: UUID
    let userId: UUID
    let username: String
    let message: String
    let timestamp: Date
    
    var isCurrentUser: Bool {
        // Will be set when displaying
        false
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    var raceId: UUID?
    var appEnvironment: AppEnvironment?
    
    @Published var messages: [ChatMessage] = []
    @Published var isSubscribed: Bool = false
    
    init(raceId: UUID? = nil) {
        self.raceId = raceId
    }
    
    /// Start listening to chat messages
    func startChat(appEnvironment: AppEnvironment) async {
        guard let raceId = raceId else {
            print("❌ No raceId provided for chat")
            return
        }
        
        self.appEnvironment = appEnvironment
        
        print("💬 Starting chat for race: \(raceId)")
        
        // Subscribe to chat broadcasts
        await appEnvironment.supabaseConnection.subscribeToChatBroadcasts(raceId: raceId)
        
        // Start processing incoming messages
        Task { @MainActor in
            await processChatMessages(appEnvironment: appEnvironment)
        }
        
        isSubscribed = true
        print("✅ Chat initialized")
    }
    
    /// Stop listening to chat messages
    func stopChat() async {
        guard let appEnvironment = appEnvironment else { return }
        
        await appEnvironment.supabaseConnection.unsubscribeFromChatBroadcasts()
        isSubscribed = false
        messages.removeAll() // Fully clear chat state when stopping
        print("🛑 Chat stopped")
    }
    
    /// Send a chat message
    func sendMessage(message: String, username: String) async {
        guard let raceId = raceId,
              let appEnvironment = appEnvironment,
              let userId = appEnvironment.supabaseConnection.currentUserId,
              !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Add message locally first (for immediate feedback)
        let chatMessage = ChatMessage(
            id: UUID(),
            userId: userId,
            username: username,
            message: message,
            timestamp: Date()
        )
        messages.append(chatMessage)
        
        // Then broadcast to others
        await appEnvironment.supabaseConnection.broadcastChatMessage(
            raceId: raceId,
            message: message,
            username: username
        )
    }
    
    /// Process incoming chat messages from broadcast
    private func processChatMessages(appEnvironment: AppEnvironment) async {
        guard let channel = appEnvironment.supabaseConnection.chatChannel else {
            print("❌ No chat channel available")
            return
        }
        
        let stream = await channel.broadcastStream(event: "chat_message")
        print("✅ Started listening to chat stream")
        
        for await message in stream {
            print("💬 Received chat message: \(message)")
            
            // Extract payload from the message
            guard let payload = message["payload"]?.objectValue else {
                print("⚠️ No payload in chat message")
                continue
            }
            
            guard let userIdString = payload["user_id"]?.stringValue,
                  let userId = UUID(uuidString: userIdString),
                  let username = payload["username"]?.stringValue,
                  let messageText = payload["message"]?.stringValue,
                  let timestampString = payload["timestamp"]?.stringValue else {
                print("⏭️ Invalid chat message format")
                continue
            }
            
            // Skip our own messages (we already added them locally)
            if userId == appEnvironment.supabaseConnection.currentUserId {
                print("⏭️ Skipping own message")
                continue
            }
            
            // Parse timestamp
            let timestamp = ISO8601DateFormatter().date(from: timestampString) ?? Date()
            
            // Create chat message
            let chatMessage = ChatMessage(
                id: UUID(),
                userId: userId,
                username: username,
                message: messageText,
                timestamp: timestamp
            )
            
            // Add to messages array
            messages.append(chatMessage)
            
            print("✅ Added chat message from \(username): \(messageText)")
        }
        
        print("🛑 Chat stream ended")
    }
}
