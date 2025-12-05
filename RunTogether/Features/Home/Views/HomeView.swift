// ==========================================
// MARK: - HomeView.swift
// ==========================================
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var selectedTab = 0
    @State private var hasAppeared = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                RunTabView()
                    .tag(0)
                    .environmentObject(appEnvironment)
                
                GroupTabView()
                    .tag(1)
                    .environmentObject(appEnvironment)
                
                FriendsTabView()
                    .tag(2)
                    .environmentObject(appEnvironment)
                
                LeaderboardTabView()
                    .tag(3)
                    .environmentObject(appEnvironment)
                
                ProfileTabView()
                    .tag(4)
                    .environmentObject(appEnvironment)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
            }
            
            customTabBar
        }
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "figure.run", title: "Run", tag: 0)
            tabButton(icon: "person.3.fill", title: "Clubs", tag: 1)
            tabButton(icon: "person.2.fill", title: "Friends", tag: 2)
            tabButton(icon: "trophy.fill", title: "Board", tag: 3)
            tabButton(icon: "person.circle.fill", title: "Profile", tag: 4)
        }
        .padding(.vertical, max(8, ResponsiveLayout.safeAreaBottomPadding))
        .background(
            Color.black
                .shadow(color: Color.white.opacity(0.1), radius: 10, x: 0, y: -5)
        )
        .frame(height: 60 + ResponsiveLayout.safeAreaBottomPadding)
    }
    
    private func tabButton(icon: String, title: String, tag: Int) -> some View {
        Button(action: {
            // Play sound only if switching to a different tab
            if selectedTab != tag {
                appEnvironment.soundManager.playTabSwitch()
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tag
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(selectedTab == tag ? .orange : .gray)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(selectedTab == tag ? .orange : .gray)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
#Preview {
    let supabaseConnection = SupabaseConnection()
    return HomeView()
        .environmentObject(AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"), supabaseConnection: supabaseConnection))
}
