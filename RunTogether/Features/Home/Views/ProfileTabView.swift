//
//  ProfileTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/22/25.
//
import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel: ProfileTabViewModel
    @State private var isEditing = false
    @State private var isSignedOut = false
    
    // Form fields
    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var location: String = ""
    
    // Store original values for cancel
    @State private var originalValues: (String, String, String, String) = ("", "", "", "")
    
    init() {
        _viewModel = StateObject(wrappedValue: ProfileTabViewModel())
    }
    
    private func loadUserData() async {
        do {
            guard let user = try await appEnvironment.supabaseConnection.getProfile() else { return }
            username = user.username
            firstName = user.first_name
            lastName = user.last_name
            location = user.location ?? ""
            originalValues = (username, firstName, lastName, location)
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }
    
    private func saveChanges() {
        Task {
            await viewModel.editProfile(
                appEnvironment: appEnvironment,
                username: username,
                firstName: firstName,
                lastName: lastName,
                location: location
            )
            isEditing = false
            originalValues = (username, firstName, lastName, location)
        }
    }
    
    private func cancelEditing() {
        (username, firstName, lastName, location) = originalValues
        isEditing = false
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile")) {
                    if isEditing {
                        TextField("Username", text: $username)
                        TextField("First Name", text: $firstName)
                        TextField("Last Name", text: $lastName)
                        TextField("Location", text: $location)
                    } else {
                        HStack {
                            Text("Username")
                            Spacer()
                            Text(username)
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text("First Name")
                            Spacer()
                            Text(firstName)
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text("Last Name")
                            Spacer()
                            Text(lastName)
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text("Location")
                            Spacer()
                            Text(location)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section {
                    if isEditing {
                        Button("Save Changes") { saveChanges() }
                            .buttonStyle(.borderedProminent)
                        
                        Button("Cancel", role: .cancel) { cancelEditing() }
                            .buttonStyle(.bordered)
                    } else {
                        Button("Edit Profile") { isEditing = true }
                    }
                    
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await viewModel.signOut(appEnvironment: appEnvironment)
                            isSignedOut = true
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                Task { await loadUserData() }
            }
            // ✅ attach here, outside the lazy `Form`
            .navigationDestination(isPresented: $isSignedOut) {
                ContentView()
                    .environmentObject(appEnvironment)
            }
        }
    }
}


#Preview {
    let supabaseConnection = SupabaseConnection()
    NavigationStack {
        ProfileTabView()
            .environmentObject(AppEnvironment(
                appUser: AppUser(
                    id: UUID().uuidString,
                    email: "test@example.com",
                    username: "testuser"
                ),
                supabaseConnection: supabaseConnection
            ))
    }
}
