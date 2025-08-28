import Foundation
import SwiftUI

class AppEnvironment: ObservableObject {
    @Published var appUser: AppUser?

    init(appUser: AppUser? = nil) {
        self.appUser = appUser
    }
}
