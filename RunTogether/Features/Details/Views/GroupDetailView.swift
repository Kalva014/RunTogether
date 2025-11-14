//
//  GroupDetailView.swift
//  RunTogether
//
// ==========================================
// MARK: - GroupDetailView.swift - COMPLETE WITH SCREEN FIX
// ==========================================
import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel = GroupDetailViewModel()
    @Environment(\.dismiss) var dismiss
    
    let club: RunClub
    
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    
    var body: some View {
        ZStack {
            // Background - FIRST with ignoresSafeArea
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    clubHeader
                    actionButtons
                    membersSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(club.name)
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
    
    // MARK: - Club Header
    private var clubHeader: some View {
        VStack(spacing: 16) {
            // Club icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 8) {
                Text(club.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if let description = club.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                // Member count badge
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(viewModel.memberProfiles.count) members")
                        .font(.subheadline)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if viewModel.isOwner {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete Club")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
                }
            } else if viewModel.isMember {
                Button(action: {
                    Task {
                        try? await viewModel.leaveRunClub(appEnvironment: appEnvironment, clubName: club.name)
                    }
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Leave Club")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
                }
            } else {
                Button(action: {
                    Task {
                        try? await viewModel.joinRunClub(appEnvironment: appEnvironment, clubName: club.name)
                    }
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Join Club")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Members Section
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Members")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.orange)
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if viewModel.clubMembers.isEmpty {
                emptyMembersView
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.memberProfiles) { member in
                        NavigationLink(destination: ProfileDetailView(username: member.username)) {
                            memberRow(member: member)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    // MARK: - Member Row
    private func memberRow(member: GroupDetailViewModel.MemberInfo) -> some View {
        HStack(spacing: 16) {
            ProfilePictureView(
                imageUrl: member.profilePictureUrl,
                username: member.username,
                size: 50
            )
            
            Text(member.username)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Empty Members View
    private var emptyMembersView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No members yet")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

#Preview("GroupDetailView") {
    NavigationStack {
        GroupDetailView(club: RunClub(
            id: 1,
            created_at: Date(),
            name: "Morning Runners",
            owner: UUID(),
            description: "Early morning running group for enthusiasts"
        ))
        .environmentObject(AppEnvironment(
            appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"),
            supabaseConnection: SupabaseConnection()
        ))
    }
}
