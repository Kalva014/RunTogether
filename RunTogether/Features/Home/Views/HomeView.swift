import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment

    var body: some View {
        TabView {
            RunTabView()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("Run")
                }
                .environmentObject(appEnvironment)
            
            GroupTabView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Groups")
                }
                .environmentObject(appEnvironment)
            
            LeaderboardTabView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Leaderboards")
                }
                .environmentObject(appEnvironment)
            
            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Profile")
                }
                .environmentObject(appEnvironment)
        }
    }
}

#Preview {
    let supabaseConnection = SupabaseConnection()
    return HomeView()
        .environmentObject(AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"), supabaseConnection: supabaseConnection))
}
