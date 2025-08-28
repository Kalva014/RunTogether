import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    @State var isSignedOut: Bool = false

    init() {
        _viewModel = StateObject(wrappedValue: HomeViewModel(appEnvironment: AppEnvironment()))
    }

    var body: some View {
        VStack {
            if let appUser = appEnvironment.appUser {
                Text("Welcome, \(appUser.username)!")
                    .font(.largeTitle)
                    .padding()
                Text("Email: \(appUser.email)")
                    .font(.headline)
                    .padding(.bottom)
            } else {
                Text("Welcome!")
                    .font(.largeTitle)
                    .padding()
            }
            
            Button("Sign Out") {
                Task {
                    await viewModel.signOut()
                    isSignedOut = true
                    dismiss()
                }
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser")))
}
