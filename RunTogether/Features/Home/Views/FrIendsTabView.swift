//
//  FriendsTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 10/15/25.
//
// ==========================================
// MARK: - FriendsTabView.swift - WITH USER SEARCH
// ==========================================
import SwiftUI

struct FriendsTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel = FriendsTabViewModel()
    @State private var searchText = ""
    @State private var activeTab: FriendTab = .myFriends
    
    enum FriendTab {
        case myFriends
        case discover
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    if viewModel.isLoading && activeTab == .myFriends {
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorView(message: error)
                    } else if activeTab == .myFriends {
                        if viewModel.friends.isEmpty {
                            emptyStateView
                        } else {
                            friendsList
                        }
                    } else {
                        // Discover tab
                        discoverView
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            if activeTab == .myFriends {
                await viewModel.loadFriends(appEnvironment: appEnvironment)
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Friends")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(activeTab == .myFriends ? "\(viewModel.friends.count) connected" : "Discover users")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Tab Switcher
            HStack(spacing: 12) {
                Button(action: {
                    activeTab = .myFriends
                    searchText = ""
                    viewModel.clearSearchState()
                    Task {
                        await viewModel.loadFriends(appEnvironment: appEnvironment)
                    }
                }) {
                    Text("My Friends")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(activeTab == .myFriends ? Color.orange : Color.clear)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    activeTab = .discover
                    searchText = ""
                    viewModel.clearSearchState()
                }) {
                    Text("Discover")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(activeTab == .discover ? Color.orange : Color.clear)
                        .cornerRadius(8)
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            // Search Bar (only for discover tab)
            if activeTab == .discover {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search by username...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchText) { _, newValue in
                            Task {
                                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    viewModel.clearSearchState()
                                } else {
                                    await viewModel.searchUsers(appEnvironment: appEnvironment, query: newValue)
                                }
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            viewModel.clearSearchState()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
        }
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
        .refreshable {
            await viewModel.loadFriends(appEnvironment: appEnvironment)
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
    
    // MARK: - Discover View
    private var discoverView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if searchText.isEmpty {
                    discoverEmptyState
                } else if viewModel.isSearching {
                    ProgressView()
                        .tint(.orange)
                        .scaleEffect(1.5)
                        .padding(.top, 40)
                } else if viewModel.searchResults.isEmpty {
                    noResultsView
                } else {
                    ForEach(viewModel.searchResults, id: \.id) { profile in
                        NavigationLink(destination: ProfileDetailView(username: profile.username)) {
                            searchResultRow(profile: profile)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
    
    private var discoverEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Search for Users")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Enter a username to find and add friends")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Users Found")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Try searching with a different username")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func searchResultRow(profile: Profile) -> some View {
        HStack(spacing: 16) {
            ProfilePictureView(
                imageUrl: profile.profile_picture_url,
                username: profile.username,
                size: 56
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.username)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(profile.first_name) \(profile.last_name)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Check if already friends
            if viewModel.friends.contains(where: { $0.username == profile.username }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Friends")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.2))
                .cornerRadius(12)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
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
            
            Button(action: {
                activeTab = .discover
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Discover Users")
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
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
