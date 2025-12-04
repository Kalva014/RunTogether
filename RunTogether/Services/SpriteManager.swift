//
//  SpriteManager.swift
//  RunTogether
//
//  Created by Kenneth Alvarez
//

import Foundation
import SpriteKit
import UIKit
import Supabase

/// Manages sprite loading, caching, and fetching from Supabase storage
@MainActor
class SpriteManager: ObservableObject {
    static let shared = SpriteManager()
    
    // MARK: - Properties
    @Published var availableSprites: [SpriteMetadata] = []
    @Published var isLoadingSprites = false
    
    // Cache for downloaded sprite textures
    private var textureCache: [String: SKTexture] = [:]
    private var imageCache: [String: UIImage] = [:]
    
    // Cache for sprite list (expires after 5 minutes)
    private var spriteListCacheTime: Date?
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // MARK: - Sprite Metadata
    struct SpriteMetadata: Identifiable, Codable {
        let id: String
        let name: String
        let url: String
        let isPremium: Bool
        
        init(id: String, name: String, url: String, isPremium: Bool = false) {
            self.id = id
            self.name = name
            self.url = url
            self.isPremium = isPremium
        }
    }
    
    // MARK: - Fetch Available Sprites
    /// Fetches the list of available sprites from Supabase storage
    func fetchAvailableSprites(supabaseClient: SupabaseClient) async throws -> [SpriteMetadata] {
        // Check cache first
        if let cacheTime = spriteListCacheTime,
           Date().timeIntervalSince(cacheTime) < cacheExpirationInterval,
           !availableSprites.isEmpty {
            print("📦 Using cached sprite list")
            return availableSprites
        }
        
        isLoadingSprites = true
        defer { isLoadingSprites = false }
        
        do {
            // List all files in the sprites bucket
            print("🔍 Fetching sprites from storage bucket...")
            let files = try await supabaseClient.storage
                .from("sprites")
                .list()
            
            print("📦 Found \(files.count) files in storage bucket")
            
            // Convert to metadata
            let sprites = files.compactMap { file -> SpriteMetadata? in
                let name = file.name
                print("📄 Processing file: \(name)")
                
                // Skip directories and non-image files
                guard !name.hasSuffix("/"),
                      name.hasSuffix(".png") || name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") else {
                    print("⏭️ Skipping \(name) - not an image file")
                    return nil
                }
                
                // Get public URL
                let url = try? supabaseClient.storage
                    .from("sprites")
                    .getPublicURL(path: name)
                
                guard let urlString = url?.absoluteString else {
                    print("❌ Failed to get URL for \(name)")
                    return nil
                }
                
                print("✅ Created sprite metadata for \(name) with URL: \(urlString)")
                
                // Determine if premium based on filename prefix
                let isPremium = name.lowercased().hasPrefix("premium_")
                
                // Clean up name for display
                let displayName = name
                    .replacingOccurrences(of: "premium_", with: "")
                    .replacingOccurrences(of: ".png", with: "")
                    .replacingOccurrences(of: ".jpg", with: "")
                    .replacingOccurrences(of: ".jpeg", with: "")
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized
                
                return SpriteMetadata(
                    id: name,
                    name: displayName,
                    url: urlString,
                    isPremium: isPremium
                )
            }
            
            // Sort: free sprites first, then by name
            let sortedSprites = sprites.sorted { lhs, rhs in
                if lhs.isPremium != rhs.isPremium {
                    return !lhs.isPremium // Free first
                }
                return lhs.name < rhs.name
            }
            
            self.availableSprites = sortedSprites
            self.spriteListCacheTime = Date()
            
            print("✅ Fetched \(sortedSprites.count) sprites from storage")
            return sortedSprites
        } catch {
            print("❌ Error fetching sprites: \(error)")
            throw error
        }
    }
    
    // MARK: - Load Sprite Texture
    /// Loads a sprite texture from URL with caching
    func loadSpriteTexture(from urlString: String?) async -> SKTexture? {
        // Return default sprite if no URL provided
        guard let urlString = urlString, !urlString.isEmpty else {
            return SKTexture(imageNamed: "MaleRunner")
        }
        
        // Check cache first
        if let cachedTexture = textureCache[urlString] {
            return cachedTexture
        }
        
        // Download and cache
        guard let url = URL(string: urlString) else {
            print("❌ Invalid sprite URL: \(urlString)")
            return SKTexture(imageNamed: "MaleRunner")
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let image = UIImage(data: data) else {
                print("❌ Failed to create image from data")
                return SKTexture(imageNamed: "MaleRunner")
            }
            
            let texture = SKTexture(image: image)
            
            // Cache the texture
            textureCache[urlString] = texture
            
            print("✅ Loaded and cached sprite from: \(urlString)")
            return texture
        } catch {
            print("❌ Error loading sprite from URL: \(error)")
            return SKTexture(imageNamed: "MaleRunner")
        }
    }
    
    // MARK: - Load Sprite Image (for UI preview)
    /// Loads a sprite as UIImage for preview in selection UI
    func loadSpriteImage(from urlString: String) async -> UIImage? {
        // Check cache first
        if let cachedImage = imageCache[urlString] {
            return cachedImage
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid sprite URL: \(urlString)")
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let image = UIImage(data: data) else {
                print("❌ Failed to create image from data")
                return nil
            }
            
            // Cache the image
            imageCache[urlString] = image
            
            return image
        } catch {
            print("❌ Error loading sprite image: \(error)")
            return nil
        }
    }
    
    // MARK: - Preload Sprites
    /// Preloads sprites for better performance during races
    func preloadSprites(urls: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = await self.loadSpriteTexture(from: url)
                }
            }
        }
    }
    
    // MARK: - Clear Cache
    /// Clears the sprite cache (useful for memory management)
    func clearCache() {
        textureCache.removeAll()
        imageCache.removeAll()
        print("🧹 Sprite cache cleared")
    }
    
    /// Clears only old cached items
    func clearOldCache(olderThan interval: TimeInterval = 3600) {
        // For now, just clear all since we don't track individual cache times
        // In production, you might want to track timestamps per item
        if let cacheTime = spriteListCacheTime,
           Date().timeIntervalSince(cacheTime) > interval {
            clearCache()
            spriteListCacheTime = nil
        }
    }
}
