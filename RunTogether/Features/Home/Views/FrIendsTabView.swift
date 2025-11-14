//
//  FriendsTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 10/15/25.
//

// ==========================================
// MARK: - FriendsTabView.swift
// ==========================================
import SwiftUI

struct FriendsTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel = FriendsTabViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    if viewModel.isLoading {
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorView(message: error)
                    } else if viewModel.friends.isEmpty {
                        emptyStateView
                    } else {
                        friendsList
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await viewModel.loadFriends(appEnvironment: appEnvironment)
        }
        .refreshable {
            await viewModel.loadFriends(appEnvironment: appEnvironment)
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Friends")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
            
            Text("\(viewModel.friends.count) connected")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    private var friendsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.friends) { friend in
                    NavigationLink(destination: ProfileDetailView(username: friend.username)) {
                        friendRow(friend: friend)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
    
    private func friendRow(friend: FriendsTabViewModel.FriendDisplay) -> some View {
        HStack(spacing: 16) {
            ProfilePictureView(
                imageUrl: friend.profilePictureUrl,
                username: friend.username,
                size: 56
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(friend.username)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let raceId = friend.activeRaceId {
                    activeRaceBadge(raceId: raceId)
                } else {
                    Text("Offline")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private func activeRaceBadge(raceId: UUID) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        .scaleEffect(1.5)
                )
            
            Text("In a race")
                .font(.subheadline)
                .foregroundColor(.green)
            
            Button(action: {
                UIPasteboard.general.string = raceId.uuidString
            }) {
                Image(systemName: "square.on.square")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(6)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)
            
            Text("Loading friends...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Oops!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                Task {
                    await viewModel.loadFriends(appEnvironment: appEnvironment)
                }
            }) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(width: 200)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Friends Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Add friends to see their activity and join races together")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 12) {
                Text("Find friends by searching for their username in the search feature")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 100)
    }
}

#Preview {
    let supabaseConnection = SupabaseConnection()
    let appEnv = AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"), supabaseConnection: supabaseConnection)
    
    return FriendsTabView()
        .environmentObject(appEnv)
}
