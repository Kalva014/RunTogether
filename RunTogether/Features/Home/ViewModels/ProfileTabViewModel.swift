//
//  ProfileTabViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/29/25.
//

import Foundation
import Supabase
import SwiftUI

@MainActor
class ProfileTabViewModel: ObservableObject {
@Published var myStats: GlobalLeaderboardEntry?
@Published var myRankedProfile: RankedProfile?
@Published var isLoadingStats = false
@Published var username: String = ""
@Published var firstName: String = ""
@Published var lastName: String = ""
@Published var location: String = ""
@Published var country: String = ""
@Published var profilePictureUrl: String?
@Published var selectedSpriteUrl: String?
@Published var isLoadingProfile = false
@Published var isSavingProfile = false
    
    private var loadedProfile: Profile?
    
    func loadStats(appEnvironment: AppEnvironment) async {
        isLoadingStats = true
        do {
            myStats = try await appEnvironment.supabaseConnection.fetchMyLeaderboardStats()
            myRankedProfile = try await appEnvironment.supabaseConnection.getRankedProfile()
        } catch {
            // Only log non-cancellation errors
            if (error as NSError).code != NSURLErrorCancelled {
                print("Failed to load profile stats: \(error)")
            }
        }
        isLoadingStats = false
    }
    
    func loadProfile(appEnvironment: AppEnvironment) async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        
        do {
            guard let profile = try await appEnvironment.supabaseConnection.getProfile() else { return }
            loadedProfile = profile
            applyProfileToForm(profile)
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }
    
    func resetForm() {
        guard let profile = loadedProfile else { return }
        applyProfileToForm(profile)
    }
    
    func saveProfile(appEnvironment: AppEnvironment, profileImageData: Data?) async {
        isSavingProfile = true
        defer { isSavingProfile = false }
        
        var updatedProfilePictureUrl = profilePictureUrl
        
        if let data = profileImageData, !data.isEmpty {
            do {
                if let uploadedUrl = try await appEnvironment.supabaseConnection.uploadProfilePicture(imageData: data) {
                    updatedProfilePictureUrl = uploadedUrl
                }
            } catch {
                print("Failed to upload profile picture: \(error)")
            }
        }
        
        await editProfile(
            appEnvironment: appEnvironment,
            username: username,
            firstName: firstName,
            lastName: lastName,
            country: country,
            profilePictureUrl: updatedProfilePictureUrl
        )
        
        profilePictureUrl = updatedProfilePictureUrl
        updateLoadedProfile()
    }
    
    func editProfile(appEnvironment: AppEnvironment, username: String?, firstName: String?, lastName: String?, country: String?, profilePictureUrl: String? = nil) async {
        do {
            try await appEnvironment.supabaseConnection.updateProfile(username: username, firstName: firstName, lastName: lastName, country: country, profilePictureUrl: profilePictureUrl)
        }
        catch {
            print("Error editing profile: \(error.localizedDescription)")
        }
    }
    
    func signOut(appEnvironment: AppEnvironment) async {
        do {
            try await appEnvironment.supabaseConnection.signOut()
            appEnvironment.appUser = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    private func applyProfileToForm(_ profile: Profile) {
        username = profile.username
        firstName = profile.first_name
        lastName = profile.last_name
        location = profile.location ?? ""
        country = profile.country ?? ""
        profilePictureUrl = profile.profile_picture_url
        selectedSpriteUrl = profile.selected_sprite_url
    }
    
    private func updateLoadedProfile() {
        guard var profile = loadedProfile else { return }
        profile.username = username
        profile.first_name = firstName
        profile.last_name = lastName
        profile.location = location
        profile.country = country
        profile.profile_picture_url = profilePictureUrl
        profile.selected_sprite_url = selectedSpriteUrl
        loadedProfile = profile
    }
}
