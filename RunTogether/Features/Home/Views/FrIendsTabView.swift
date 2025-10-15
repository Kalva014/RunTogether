//
//  FriendsTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 10/15/25.
//

import SwiftUI

struct FriendsTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel = FriendsTabViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading friends...")
                        .padding()
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text(error)
                            .foregroundColor(.red)
                        Button("Retry") {
                            Task {
                                await viewModel.loadFriends(appEnvironment: appEnvironment)
                            }
                        }
                    }
                } else if viewModel.friends.isEmpty {
                    ContentUnavailableView("No Friends Yet", systemImage: "person.2.slash.fill", description: Text("Add or accept friend requests to see them here."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.friends, id: \.id) { friend in
                                NavigationLink(destination: ProfileDetailView(username: friend.username)) {
                                    FriendRow(friend: friend)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await viewModel.loadFriends(appEnvironment: appEnvironment)
        }
        .refreshable {
            await viewModel.loadFriends(appEnvironment: appEnvironment)
        }
    }
}

struct FriendRow: View {
    let friend: Profile
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar (use first letter of username)
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(String(friend.username.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.username)
                    .font(.headline)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
    }
}

#Preview {
    let supabaseConnection = SupabaseConnection()
    let appEnv = AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"), supabaseConnection: supabaseConnection)
    
    return FriendsTabView()
        .environmentObject(appEnv)
}
