//
//  ChatView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 11/2/25.
//
// ==========================================
// MARK: - ChatView.swift - COMPLETE
// ==========================================
import SwiftUI

struct ChatView: View {
    @StateObject var viewModel: ChatViewModel
    @EnvironmentObject var appEnvironment: AppEnvironment
    @Binding var isPresented: Bool
    
    @State private var messageText: String = ""
    @State private var username: String = "You"
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Messages
                messagesView
                
                // Input
                messageInput
            }
            .background(Color(white: 0.1))
            .cornerRadius(20, corners: [.topLeft, .topRight])
        }
        .onAppear {
            Task {
                if let profile = try? await appEnvironment.supabaseConnection.getProfile() {
                    username = profile.username ?? "You"
                }
            }
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Race Chat")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(viewModel.messages.count) messages")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.5))
    }
    
    // MARK: - Messages View
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.messages) { message in
                            chatMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(16)
            }
            .frame(height: 400)
            .onChange(of: viewModel.messages.count) { _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No messages yet")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Be the first to say something!")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Message Row
    private func chatMessageRow(message: ChatMessage) -> some View {
        let isCurrentUser = message.userId == appEnvironment.supabaseConnection.currentUserId
        
        return HStack {
            if isCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 6) {
                // Username and time
                HStack(spacing: 8) {
                    if !isCurrentUser {
                        Text(message.username)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    if isCurrentUser {
                        Text(message.username)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
                
                // Message bubble
                Text(message.message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isCurrentUser
                            ? Color.orange.opacity(0.8)
                            : Color.white.opacity(0.15)
                    )
                    .cornerRadius(16, corners: isCurrentUser
                        ? [.topLeft, .topRight, .bottomLeft]
                        : [.topLeft, .topRight, .bottomRight]
                    )
            }
            .frame(maxWidth: 250, alignment: isCurrentUser ? .trailing : .leading)
            
            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    // MARK: - Message Input
    private var messageInput: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $messageText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.white)
            
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundColor(messageText.isEmpty ? .gray : .black)
                    .frame(width: 44, height: 44)
                    .background(messageText.isEmpty ? Color.gray.opacity(0.3) : Color.orange)
                    .cornerRadius(22)
            }
            .disabled(messageText.isEmpty)
        }
        .padding(16)
        .background(Color.black.opacity(0.5))
    }
    
    // MARK: - Actions
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
