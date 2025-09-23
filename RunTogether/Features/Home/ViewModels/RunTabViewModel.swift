import Foundation
import Supabase
import SwiftUI

class RunTabViewModel: ObservableObject {
    var appEnvironment: AppEnvironment
    private lazy var supabaseConnection = SupabaseConnection()

    init(appEnvironment: AppEnvironment) {
        self.appEnvironment = appEnvironment
    }
    
//    func testSupabase() async {
//        supabaseConnection.joinRandomRace(mode: "Race")
//    }

    func signOut() async {
        do {
            try await supabaseConnection.signOut()
            appEnvironment.appUser = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}
