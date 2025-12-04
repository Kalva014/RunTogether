//
//  SpriteSelectionView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez
//

import SwiftUI

struct SpriteSelectionView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var spriteManager = SpriteManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSpriteUrl: String?
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let currentSpriteUrl: String?
    let onSpriteSelected: (String?) -> Void
    
    init(currentSpriteUrl: String?, onSpriteSelected: @escaping (String?) -> Void) {
        self.currentSpriteUrl = currentSpriteUrl
        self.onSpriteSelected = onSpriteSelected
        _selectedSpriteUrl = State(initialValue: currentSpriteUrl)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    header
                    
                    if spriteManager.isLoadingSprites {
                        loadingView
                    } else if spriteManager.availableSprites.isEmpty {
                        emptyStateView
                    } else {
                        spriteGridView
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            Task {
                do {
                    print("🎨 SpriteSelectionView appeared, fetching sprites...")
                    let sprites = try await spriteManager.fetchAvailableSprites(supabaseClient: appEnvironment.supabaseConnection.client)
                    print("🎨 Fetched \(sprites.count) sprites successfully")
                    
                    if sprites.isEmpty {
                        print("⚠️ No sprites found in storage bucket")
                    }
                } catch {
                    print("❌ Error loading sprites: \(error)")
                    errorMessage = "Failed to load sprites: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Choose Your Sprite")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: saveSelection) {
                    if isSaving {
                        ProgressView()
                            .tint(.orange)
                    } else {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                }
                .frame(width: 60)
                .disabled(isSaving || selectedSpriteUrl == currentSpriteUrl)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 10)
            
            Text("Select a sprite to represent you in races")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .background(Color.black)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.orange)
                .scaleEffect(1.5)
            
            Text("Loading sprites...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No sprites available")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Check back later for new sprites!")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var spriteGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(spriteManager.availableSprites) { sprite in
                    SpriteCard(
                        sprite: sprite,
                        isSelected: selectedSpriteUrl == sprite.url,
                        onSelect: { selectedSpriteUrl = sprite.url }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
    
    private func saveSelection() {
        isSaving = true
        Task {
            do {
                try await appEnvironment.supabaseConnection.updateProfile(selectedSpriteUrl: selectedSpriteUrl)
                await MainActor.run {
                    onSpriteSelected(selectedSpriteUrl)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save sprite: \(error.localizedDescription)"
                    showError = true
                    isSaving = false
                }
            }
        }
    }
}

struct SpriteCard: View {
    let sprite: SpriteManager.SpriteMetadata
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var spriteImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 100)
                    
                    if isLoading {
                        ProgressView()
                            .tint(.orange)
                    } else if let image = spriteImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 80)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                    
                    if sprite.isPremium {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                    .padding(6)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                }
                
                Text(sprite.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.orange.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            spriteImage = await SpriteManager.shared.loadSpriteImage(from: sprite.url)
            isLoading = false
        }
    }
}

#Preview {
    SpriteSelectionView(currentSpriteUrl: nil) { _ in }
        .environmentObject(AppEnvironment(
            appUser: AppUser(
                id: UUID().uuidString,
                email: "test@example.com",
                username: "testuser"
            ),
            supabaseConnection: SupabaseConnection()
        ))
}
