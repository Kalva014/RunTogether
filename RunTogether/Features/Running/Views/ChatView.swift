//
//  ChatView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 11/2/25.
//

import SwiftUI

struct ChatView: View {
    @StateObject var viewModel: ChatViewModel
    @EnvironmentObject var appEnvironment: AppEnvironment
    @Binding var isPresented: Bool
    
    @State private var messageText: String = ""
    @State private var username: String = "You"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Race Chat")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.black.opacity(0.9))
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Messages ScrollView
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            chatMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .background(Color.black.opacity(0.7))
                .onChange(of: viewModel.messages.count) { _ in
                    // Auto-scroll to bottom when new message arrives
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Message Input
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(height: 40)
                
                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(messageText.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(22)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color.black.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.95))
        .onAppear {
            Task {
                await viewModel.startChat(appEnvironment: appEnvironment)
                
                // Fetch username
                if let profile = try? await appEnvironment.supabaseConnection.getProfile() {
                    username = profile.username ?? "You"
                }
            }
        }
        .onDisappear {
            Task {
                await viewModel.stopChat()
            }
        }
    }
    
    private func chatMessageRow(message: ChatMessage) -> some View {
        let isCurrentUser = message.userId == appEnvironment.supabaseConnection.currentUserId
        
        return HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.username)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isCurrentUser ? .yellow : .cyan)
                
                Text(message.message)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.blue.opacity(0.8) : Color.gray.opacity(0.6))
                    .cornerRadius(16)
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: 250, alignment: isCurrentUser ? .trailing : .leading)
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        Task {
            await viewModel.sendMessage(message: trimmedMessage, username: username)
            messageText = ""
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ChatView(viewModel: ChatViewModel(raceId: UUID()), isPresented: .constant(true))
        .environmentObject(AppEnvironment(
            appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"),
            supabaseConnection: SupabaseConnection()
        ))
}
