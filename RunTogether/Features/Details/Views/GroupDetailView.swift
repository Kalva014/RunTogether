//
//  GroupDetailView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 10/9/25.
//
import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel = GroupDetailViewModel()
    @Environment(\.dismiss) var dismiss
    
    let club: RunClub
    
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Club Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(club.name)
                        .font(.largeTitle)
                        .bold()
                    
                    if let description = club.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 12) {
                    if viewModel.isOwner {
                        // Owner Actions
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Label("Delete Club", systemImage: "trash")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                    } else if viewModel.isMember {
                        // Member Actions
                        Button(action: {
                            Task {
                                try? await viewModel.leaveRunClub(appEnvironment: appEnvironment, clubName: club.name)
                            }
                        }) {
                            Label("Leave Club", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                    } else {
                        // Non-Member Actions
                        Button(action: {
                            Task {
                                try? await viewModel.joinRunClub(appEnvironment: appEnvironment, clubName: club.name)
                            }
                        }) {
                            Label("Join Club", systemImage: "person.badge.plus")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Members Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Members (\(viewModel.memberProfiles.count))")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if viewModel.clubMembers.isEmpty {
                        Text("No members yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        VStack(spacing: 0) {
                            ForEach(viewModel.memberProfiles) { member in
                                NavigationLink(destination: ProfileDetailView(username: member.username)) {
                                    HStack {
                                        ProfilePictureView(imageUrl: member.profilePictureUrl, username: member.username, size: 44)
                                        
                                        Text(member.username)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if member.id != viewModel.memberProfiles.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Club Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Club", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await viewModel.deleteRunClub(appEnvironment: appEnvironment, clubName: club.name)
                        dismiss()
                    } catch {
                        showError = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this club? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .task {
            await viewModel.fetchClubMembers(appEnvironment: appEnvironment, clubName: club.name)
            await viewModel.checkMembership(appEnvironment: appEnvironment, clubName: club.name)
            await viewModel.checkOwnership(appEnvironment: appEnvironment, ownerId: club.owner)
        }
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(club: RunClub(
            id: 1,
            created_at: Date(),
            name: "Morning Runners",
            owner: UUID(),
            description: "Early morning running group for enthusiasts",
        ))
        .environmentObject(AppEnvironment(
            appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"),
            supabaseConnection: SupabaseConnection()
        ))
    }
}
