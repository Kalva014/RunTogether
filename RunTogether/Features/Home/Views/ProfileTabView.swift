//
//  ProfileTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/22/25.
//
import SwiftUI
import PhotosUI

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
    @State private var profilePictureUrl: String? = nil
    
    // Image picker
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isUploadingImage = false
    
    // Store original values for cancel
    @State private var originalValues: (String, String, String, String, String?) = ("", "", "", "", nil)
    
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
            profilePictureUrl = user.profile_picture_url
            originalValues = (username, firstName, lastName, location, profilePictureUrl)
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }
    
    private func saveChanges() {
        Task {
            // Upload image if a new one was selected
            if let selectedImage = selectedImage {
                isUploadingImage = true
                do {
                    guard let imageData = selectedImage.jpegData(compressionQuality: 0.8) else {
                        isUploadingImage = false
                        return
                    }
                    
                    if let uploadedUrl = try await appEnvironment.supabaseConnection.uploadProfilePicture(imageData: imageData) {
                        profilePictureUrl = uploadedUrl
                    }
                } catch {
                    print("Failed to upload profile picture: \(error)")
                }
                isUploadingImage = false
            }
            
            await viewModel.editProfile(
                appEnvironment: appEnvironment,
                username: username,
                firstName: firstName,
                lastName: lastName,
                location: location,
                profilePictureUrl: profilePictureUrl
            )
            isEditing = false
            originalValues = (username, firstName, lastName, location, profilePictureUrl)
            selectedImage = nil // Clear selected image after saving
        }
    }
    
    private func cancelEditing() {
        (username, firstName, lastName, location, profilePictureUrl) = originalValues
        selectedImage = nil
        isEditing = false
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile Picture")) {
                    HStack {
                        Spacer()
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            ProfilePictureView(imageUrl: profilePictureUrl, username: username, size: 100)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    if isEditing {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Change Profile Picture")
                            }
                        }
                        .onChange(of: selectedItem) { oldValue, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    selectedImage = image
                                }
                            }
                        }
                    }
                }
                
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
                        Button("Save Changes") {
                            saveChanges()
                        } 
                        .buttonStyle(.borderedProminent)
                        .disabled(isUploadingImage)
                        
                        if isUploadingImage {
                            HStack {
                                Spacer()
                                ProgressView("Uploading...")
                                Spacer()
                            }
                        }
                        
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
