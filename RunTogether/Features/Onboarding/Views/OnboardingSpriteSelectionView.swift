//
//  OnboardingSpriteSelectionView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez
//

import SwiftUI

struct OnboardingSpriteSelectionView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var spriteManager = SpriteManager.shared
    @Binding var selectedSpriteUrl: String?
    
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                    .shadow(color: .orange.opacity(0.3), radius: 20)
                
                Text("Choose Your Sprite")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Select how you'll appear in races")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            
            // Sprite Grid
            if isLoading {
                ProgressView()
                    .tint(.orange)
                    .scaleEffect(1.5)
            } else if spriteManager.availableSprites.isEmpty {
                Text("No sprites available")
                    .foregroundColor(.gray)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        // Default sprite option
                        OnboardingSpriteCard(
                            sprite: nil,
                            isSelected: selectedSpriteUrl == nil,
                            onSelect: { selectedSpriteUrl = nil }
                        )
                        
                        // Custom sprites
                        ForEach(spriteManager.availableSprites.prefix(8)) { sprite in
                            OnboardingSpriteCard(
                                sprite: sprite,
                                isSelected: selectedSpriteUrl == sprite.url,
                                onSelect: { selectedSpriteUrl = sprite.url }
                            )
                        }
                    }
                    .padding(.horizontal, 30)
                }
                .frame(maxHeight: 300)
            }
            
            Text("You can change this later in your profile")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadSprites()
        }
    }
    
    private func loadSprites() {
        Task {
            do {
                isLoading = true
                _ = try await spriteManager.fetchAvailableSprites(supabaseClient: appEnvironment.supabaseConnection.client)
                isLoading = false
            } catch {
                errorMessage = "Failed to load sprites: \(error.localizedDescription)"
                showError = true
                isLoading = false
            }
        }
    }
}

struct OnboardingSpriteCard: View {
    let sprite: SpriteManager.SpriteMetadata?
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var spriteImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 70)
                    
                    if sprite == nil {
                        // Default sprite
                        VStack(spacing: 4) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                            Text("Default")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    } else if isLoading {
                        ProgressView()
                            .tint(.orange)
                    } else if let image = spriteImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 50)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                
                if let sprite = sprite {
                    Text(sprite.name)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            if let sprite = sprite {
                spriteImage = await SpriteManager.shared.loadSpriteImage(from: sprite.url)
                isLoading = false
            } else {
                isLoading = false
            }
        }
    }
}

#Preview {
    OnboardingSpriteSelectionView(selectedSpriteUrl: .constant(nil))
        .environmentObject(AppEnvironment(
            appUser: AppUser(
                id: UUID().uuidString,
                email: "test@example.com",
                username: "testuser"
            ),
            supabaseConnection: SupabaseConnection()
        ))
}
