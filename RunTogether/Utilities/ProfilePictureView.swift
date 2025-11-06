//
//  ProfilePictureView.swift
//  RunTogether
//
//  Created for profile picture display
//

import SwiftUI

struct ProfilePictureView: View {
    let imageUrl: String?
    let username: String
    let size: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadError = false
    
    init(imageUrl: String?, username: String, size: CGFloat = 44) {
        self.imageUrl = imageUrl
        self.username = username
        self.size = size
    }
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if loadError || imageUrl == nil {
                // Fallback to initials
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(username.prefix(1)).uppercased())
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundColor(.blue)
                    )
            } else {
                // Loading state
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
            }
        }
        .task {
            await loadImage()
        }
        .onChange(of: imageUrl) { _, _ in
            Task {
                await loadImage()
            }
        }
    }
    
    private func loadImage() async {
        guard let imageUrl = imageUrl, let url = URL(string: imageUrl) else {
            loadError = true
            return
        }
        
        isLoading = true
        loadError = false
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let loadedImage = UIImage(data: data) {
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.loadError = true
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.loadError = true
                self.isLoading = false
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfilePictureView(imageUrl: nil, username: "JohnDoe", size: 60)
        ProfilePictureView(imageUrl: "https://example.com/image.jpg", username: "JaneSmith", size: 60)
        ProfilePictureView(imageUrl: nil, username: "Test", size: 44)
    }
    .padding()
}

