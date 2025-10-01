import Foundation
import SwiftUI

class AppEnvironment: ObservableObject {
    @Published var appUser: AppUser?
    @Published var supabaseConnection: SupabaseConnection

    init(appUser: AppUser? = nil, supabaseConnection: SupabaseConnection) {
        self.appUser = appUser
        self.supabaseConnection = supabaseConnection
        
        // Check authentication state on initialization
        Task {
            await checkAuthenticationState()
        }
    }
    
    @MainActor
    private func checkAuthenticationState() async {
        // Wait for SupabaseConnection to finish checking its authentication state
        while !supabaseConnection.isAuthenticated && supabaseConnection.currentUserId == nil {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        // If user is authenticated, set the appUser
        if supabaseConnection.isAuthenticated, let userId = supabaseConnection.currentUserId {
            do {
                let session = try await supabaseConnection.client.auth.session
                let user = session.user
                var username = ""
                if let usernameAnyJSON = user.userMetadata["username"], let usernameString = usernameAnyJSON.stringValue {
                    username = usernameString
                }
                
                self.appUser = AppUser(id: user.id.uuidString, email: user.email ?? "", username: username)
                print("User session restored on app launch: \(user.email ?? "unknown")")
            } catch {
                print("Error restoring user session: \(error.localizedDescription)")
            }
        }
    }
}
