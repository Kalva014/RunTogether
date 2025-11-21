//
//  ProfileTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/22/25.
//
// ==========================================
// MARK: - ProfileTabView.swift - WITH PHOTO PERMISSIONS
// ==========================================
import SwiftUI
import PhotosUI

struct ProfileTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject var viewModel: ProfileTabViewModel
    @State private var isEditing = false
    @State private var isSignedOut = false
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showPhotoPermissionAlert = false
    
    init() {
        _viewModel = StateObject(wrappedValue: ProfileTabViewModel())
    }
    
    private func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    print("✅ Photo library access granted")
                case .denied, .restricted:
                    showPhotoPermissionAlert = true
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func saveChanges() {
        Task {
            let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
            await viewModel.saveProfile(appEnvironment: appEnvironment, profileImageData: imageData)
            selectedImage = nil
            isEditing = false
        }
    }
    
    private func cancelEditing() {
        viewModel.resetForm()
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
            .alert("Photo Library Access Required", isPresented: $showPhotoPermissionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Please enable photo library access in Settings to change your profile picture.")
            }
        }
        .onAppear {
            Task {
                await viewModel.loadProfile(appEnvironment: appEnvironment)
                await viewModel.loadStats(appEnvironment: appEnvironment)
            }
            // Request permission on first appearance
            requestPhotoLibraryPermission()
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
                    ProfilePictureView(imageUrl: viewModel.profilePictureUrl, username: viewModel.username, size: 100)
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
                            // Check permission before loading photo
                            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                            
                            guard status == .authorized || status == .limited else {
                                // Request permission if not granted
                                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                                    if newStatus == .authorized || newStatus == .limited {
                                        Task {
                                            await loadSelectedPhoto(from: newValue)
                                        }
                                    } else {
                                        DispatchQueue.main.async {
                                            showPhotoPermissionAlert = true
                                            selectedItem = nil
                                        }
                                    }
                                }
                                return
                            }
                            
                            // Permission already granted, load photo
                            await loadSelectedPhoto(from: newValue)
                        }
                    }
                }
            }
            
            if !isEditing {
                VStack(spacing: 4) {
                    Text("@\(viewModel.username)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if !viewModel.firstName.isEmpty || !viewModel.lastName.isEmpty {
                        Text("\(viewModel.firstName) \(viewModel.lastName)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    if !viewModel.location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(viewModel.location)
                                .font(.subheadline)
                        }
                        .foregroundColor(.gray)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func loadSelectedPhoto(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            await MainActor.run {
                selectedImage = image
            }
        }
    }
    
    private var statsSection: some View {
        HStack(spacing: 20) {
            statItem(
                value: viewModel.isLoadingStats ? "..." : "\(Int(viewModel.myStats?.total_races_completed ?? 0))", 
                label: "Runs"
            )
            
            Divider()
                .background(Color.white.opacity(0.2))
                .frame(height: 40)
            
            statItem(
                value: viewModel.isLoadingStats ? "..." : String(format: "%.1f km", (viewModel.myStats?.total_distance_covered ?? 0) / 1000), 
                label: "Distance"
            )
            
            Divider()
                .background(Color.white.opacity(0.2))
                .frame(height: 40)
            
            statItem(
                value: viewModel.isLoadingStats ? "..." : "\(viewModel.myStats?.top_three_finishes ?? 0)", 
                label: "Top 3"
            )
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
                    editField(title: "Username", text: $viewModel.username, placeholder: "Enter username")
                    editField(title: "First Name", text: $viewModel.firstName, placeholder: "Enter first name")
                    editField(title: "Last Name", text: $viewModel.lastName, placeholder: "Enter last name")
                    editField(title: "Location", text: $viewModel.location, placeholder: "Enter location")
                }
            } else {
                VStack(spacing: 0) {
                    profileRow(icon: "person.fill", title: "Username", value: viewModel.username)
                    Divider().background(Color.white.opacity(0.1))
                    profileRow(icon: "person.text.rectangle", title: "First Name", value: viewModel.firstName)
                    Divider().background(Color.white.opacity(0.1))
                    profileRow(icon: "person.text.rectangle.fill", title: "Last Name", value: viewModel.lastName)
                    Divider().background(Color.white.opacity(0.1))
                    profileRow(icon: "location.fill", title: "Location", value: viewModel.location)
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
                    Group {
                        if viewModel.isSavingProfile {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Save Changes")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(viewModel.isSavingProfile ? .gray : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.isSavingProfile ? Color.gray.opacity(0.3) : Color.orange)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isSavingProfile)
                
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
