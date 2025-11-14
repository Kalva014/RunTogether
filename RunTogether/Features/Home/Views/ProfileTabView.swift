//
//  ProfileTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/22/25.
//
// ==========================================
// MARK: - ProfileTabView.swift
// ==========================================
import SwiftUI
import PhotosUI

struct ProfileTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel: ProfileTabViewModel
    @State private var isEditing = false
    @State private var isSignedOut = false
    
    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var location: String = ""
    @State private var profilePictureUrl: String? = nil
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isUploadingImage = false
    
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
            selectedImage = nil
        }
    }
    
    private func cancelEditing() {
        (username, firstName, lastName, location, profilePictureUrl) = originalValues
        selectedImage = nil
        isEditing = false
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        profileHeader
                        statsSection
                        profileDetails
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .background(
                NavigationLink(isActive: $isSignedOut) {
                    ContentView()
                        .environmentObject(appEnvironment)
                } label: { EmptyView() }
                    .hidden()
            )
        }
        .onAppear {
            Task { await loadUserData() }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    ProfilePictureView(imageUrl: profilePictureUrl, username: username, size: 100)
                }
                
                if isEditing {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        ZStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
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
            
            if !isEditing {
                VStack(spacing: 4) {
                    Text("@\(username)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if !firstName.isEmpty || !lastName.isEmpty {
                        Text("\(firstName) \(lastName)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    if !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(location)
                                .font(.subheadline)
                        }
                        .foregroundColor(.gray)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var statsSection: some View {
        HStack(spacing: 20) {
            statItem(value: "0", label: "Runs")
            
            Divider()
                .background(Color.white.opacity(0.2))
                .frame(height: 40)
            
            statItem(value: "0 km", label: "Distance")
            
            Divider()
                .background(Color.white.opacity(0.2))
                .frame(height: 40)
            
            statItem(value: "--:--", label: "Avg Pace")
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var profileDetails: some View {
        VStack(spacing: 16) {
            if isEditing {
                VStack(spacing: 12) {
                    editField(title: "Username", text: $username, placeholder: "Enter username")
                    editField(title: "First Name", text: $firstName, placeholder: "Enter first name")
                    editField(title: "Last Name", text: $lastName, placeholder: "Enter last name")
                    editField(title: "Location", text: $location, placeholder: "Enter location")
                }
            } else {
                VStack(spacing: 0) {
                    profileRow(icon: "person.fill", title: "Username", value: username)
                    Divider().background(Color.white.opacity(0.1))
                    profileRow(icon: "person.text.rectangle", title: "First Name", value: firstName)
                    Divider().background(Color.white.opacity(0.1))
                    profileRow(icon: "person.text.rectangle.fill", title: "Last Name", value: lastName)
                    Divider().background(Color.white.opacity(0.1))
                    profileRow(icon: "location.fill", title: "Location", value: location)
                }
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
            }
        }
    }
    
    private func editField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            TextField(placeholder, text: text)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.white)
        }
    }
    
    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.orange)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value.isEmpty ? "Not set" : value)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isEditing {
                Button(action: saveChanges) {
                    if isUploadingImage {
                        ProgressView()
                            .tint(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .cornerRadius(12)
                    } else {
                        Text("Save Changes")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                }
                .disabled(isUploadingImage)
                
                Button(action: cancelEditing) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
            } else {
                Button(action: { isEditing = true }) {
                    Text("Edit Profile")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
            }
            
            Button(action: {
                Task {
                    await viewModel.signOut(appEnvironment: appEnvironment)
                    isSignedOut = true
                }
            }) {
                Text("Sign Out")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
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
