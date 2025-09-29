import Foundation
import Supabase
import SwiftUI

class LogInViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    private lazy var supabaseConnection = SupabaseConnection()

    func signIn(email: String, password: String, appEnvironment: AppEnvironment) async -> Bool {
        do {
            _ = try await supabaseConnection.signIn(email: email, password: password)
            
            // Assuming successful sign-in, retrieve user data
            let session = try await supabaseConnection.client.auth.session
            
            // user is not optional here, it's directly accessible
            let user = session.user
            var username = ""
            if let usernameAnyJSON = user.userMetadata["username"], let usernameString = usernameAnyJSON.stringValue {
                username = usernameString
            }
            
            // Assign to environment so user info can be passed to other views
            appEnvironment.appUser = AppUser(id: user.id.uuidString, email: user.email ?? "", username: username)
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("Error signing in: \(error.localizedDescription)")
            
            return false
        }
    }
}
