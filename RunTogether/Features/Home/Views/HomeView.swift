import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
//    @StateObject private var viewModel: RunTabViewModel
//    
//    init() {
//        _viewModel = StateObject(wrappedValue: RunTabViewModel(appEnvironment: AppEnvironment()))
//    }

    var body: some View {
        TabView {
            RunTabView()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("Run")
                }
            
            GroupTabView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Groups")
                }
            
            LeaderboardTabView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Leaderboards")
                }
            
            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Profile")
                }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser")))
}
