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
                            ForEach(viewModel.friends) { friend in
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
    let friend: FriendsTabViewModel.FriendDisplay
    
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                ProfilePictureView(imageUrl: friend.profilePictureUrl, username: friend.username, size: 44)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.username)
                        .font(.headline)
                    
                    if let raceId = friend.activeRaceId {
                        HStack(spacing: 6) {
                            Text("🏁 In race:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(raceId.uuidString.prefix(8) + "…")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            
                            Button(action: {
                                UIPasteboard.general.string = raceId.uuidString
                                withAnimation { copied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation { copied = false }
                                }
                            }) {
                                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(copied ? .green : .secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}


#Preview {
    let supabaseConnection = SupabaseConnection()
    let appEnv = AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"), supabaseConnection: supabaseConnection)
    
    return FriendsTabView()
        .environmentObject(appEnv)
}
