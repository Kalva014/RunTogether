//
//  GroupTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/22/25.
//
// ==========================================
// MARK: - GroupTabView.swift
// ==========================================
//
//  GroupTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/22/25.
//
// ==========================================
// MARK: - GroupTabView.swift - WITH MY CLUBS SECTION
// ==========================================
import SwiftUI

struct GroupTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel: GroupTabViewModel
    @State private var searchText = ""
    @State private var showingCreateClub = false
    @State private var newClubName = ""
    @State private var newClubDescription = ""
    @State private var isSearching = false
    @State private var activeTab: ClubTab = .myClubs
    
    enum ClubTab {
        case myClubs
        case discover
    }
    
    init() {
        _viewModel = StateObject(wrappedValue: GroupTabViewModel())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    if viewModel.isLoading && viewModel.runClubs.isEmpty {
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorView(message: error)
                    } else {
                        clubsList
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCreateClub) {
                createClubSheet
            }
        }
        .task {
            await loadClubs()
        }
    }
    
    private func loadClubs() async {
        if activeTab == .myClubs {
            try? await viewModel.fetchRunClubs(appEnvironment: appEnvironment)
        } else {
            try? await viewModel.fetchAllRunClubs(appEnvironment: appEnvironment)
        }
    }
    
    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Run Clubs")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(activeTab == .myClubs ? "\(viewModel.runClubs.count) clubs" : "Discover new clubs")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {
                    showingCreateClub = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                }
            }
            
            // Tab Switcher
            HStack(spacing: 12) {
                Button(action: {
                    activeTab = .myClubs
                    Task { await loadClubs() }
                }) {
                    Text("My Clubs")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(activeTab == .myClubs ? Color.orange : Color.clear)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    activeTab = .discover
                    Task { await loadClubs() }
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
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search clubs...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        isSearching = true
                        Task {
                            await viewModel.searchRunClubs(appEnvironment: appEnvironment, searchText: searchText)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        isSearching = false
                        Task { await loadClubs() }
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
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    private var clubsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.runClubs.isEmpty {
                    emptyStateView
                } else {
                    ForEach(viewModel.runClubs) { club in
                        NavigationLink(destination: GroupDetailView(club: club)) {
                            clubRow(club: club)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .refreshable {
            await loadClubs()
        }
    }
    
    private func clubRow(club: RunClub) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(club.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let description = club.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(activeTab == .myClubs ? "No clubs yet" : "No clubs to discover")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            if activeTab == .myClubs {
                Text("Join or create a club to get started")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var createClubSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Club Name")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        TextField("Enter club name", text: $newClubName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (Optional)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $newClubDescription)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            Task {
                                do {
                                    try await viewModel.createRunClub(
                                        appEnvironment: appEnvironment,
                                        name: newClubName,
                                        description: newClubDescription
                                    )
                                    newClubName = ""
                                    newClubDescription = ""
                                    showingCreateClub = false
                                } catch {}
                            }
                        }) {
                            Text("Create Club")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(newClubName.isEmpty ? Color.gray : Color.orange)
                                .cornerRadius(12)
                        }
                        .disabled(newClubName.isEmpty)
                        
                        Button(action: {
                            newClubName = ""
                            newClubDescription = ""
                            showingCreateClub = false
                        }) {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Create Run Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Create Run Club")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)
            
            Text("Loading clubs...")
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
                Task { await loadClubs() }
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
        .padding(.bottom, 100)
    }
}

#Preview {
    GroupTabView()
        .environmentObject(AppEnvironment(
            appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"),
            supabaseConnection: SupabaseConnection()
        ))
}
