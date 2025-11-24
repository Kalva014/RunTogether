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
    @Published var currentUsername: String = "You"
    
    init(raceId: UUID? = nil) {
        self.raceId = raceId
    }
    
    private var currentUserId: UUID?
    
    /// Start listening to chat messages
    func startChat(appEnvironment: AppEnvironment) async {
        // Only stop chat if changing raceId (prevents double-unsubscribe race bugs)
        if self.appEnvironment != nil && self.raceId != appEnvironment.supabaseConnection.currentChatRaceId {
            print("[ChatViewModel] Switching chats from raceId: \(self.raceId?.uuidString ?? "nil") to \(appEnvironment.supabaseConnection.currentChatRaceId?.uuidString ?? "nil") (will clear state)")
            await stopChat()
            self.messages.removeAll()
        }
        guard let raceId = raceId else {
            print("❌ No raceId provided for chat")
            return
        }
        self.appEnvironment = appEnvironment
        currentUserId = appEnvironment.supabaseConnection.currentUserId
        print("💬 [ChatViewModel] Starting chat for race: \(raceId)")
        await appEnvironment.supabaseConnection.subscribeToChatBroadcasts(raceId: raceId)
        await loadCurrentUsername(from: appEnvironment)
        Task { @MainActor in
            await processChatMessages(appEnvironment: appEnvironment)
        }
        isSubscribed = true
        print("✅ [ChatViewModel] Chat initialized for raceId=\(raceId.uuidString)")
    }
    
    /// Stop listening to chat messages
    func stopChat() async {
        guard let appEnvironment = appEnvironment else { return }
        await appEnvironment.supabaseConnection.unsubscribeFromChatBroadcasts()
        isSubscribed = false
        print("🛑 [ChatViewModel] Chat stopped for raceId=\(raceId?.uuidString ?? "nil")")
        self.messages.removeAll()
    }
    
    /// Send a chat message
    func sendMessage(_ message: String) async {
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
            username: currentUsername,
            message: message,
            timestamp: Date()
        )
        messages.append(chatMessage)
        
        // Then broadcast to others
        await appEnvironment.supabaseConnection.broadcastChatMessage(
            raceId: raceId,
            message: message,
            username: currentUsername
        )
    }
    
    /// Process incoming chat messages from broadcast
    private func processChatMessages(appEnvironment: AppEnvironment) async {
        guard let channel = appEnvironment.supabaseConnection.chatChannel else {
            print("❌ No chat channel available")
            return
        }
        
        let stream = channel.broadcastStream(event: "chat_message")
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
    
    func isMessageFromCurrentUser(_ message: ChatMessage) -> Bool {
        guard let appEnvironment = appEnvironment else { return false }
        return message.userId == appEnvironment.supabaseConnection.currentUserId
    }
    
    private func loadCurrentUsername(from appEnvironment: AppEnvironment) async {
        if let profile = try? await appEnvironment.supabaseConnection.getProfile() {
            currentUsername = profile.username
        } else if let fallback = appEnvironment.appUser?.username {
            currentUsername = fallback
        } else {
            currentUsername = "You"
        }
    }
}
