import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    @State var isSignedOut: Bool = false
    @State private var isTreadmillMode: Bool = false
    @State private var selectedDistance: String = "5K" // Default 5k
    let distances = ["5K", "10K", "Half Marathon(21.1K)", "Full Marathon(42.2K)"]

    init() {
        _viewModel = StateObject(wrappedValue: HomeViewModel(appEnvironment: AppEnvironment()))
    }

    var body: some View {
        NavigationStack {
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
                
                Picker("Distance", selection: $selectedDistance) {
                    ForEach(distances, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.menu) // or .segmented, etc.
                .padding()
                
                Toggle("Treadmill Mode", isOn: $isTreadmillMode)
                    .font(.headline)
                    .padding()
                    .frame(width: 250)
                
                // Separate NavigationLinks for Normal Mode and Casual Group Run
                NavigationLink(destination: RunningView(
                    mode: "Normal",
                    isTreadmillMode: isTreadmillMode,
                    distance: selectedDistance
                )) {
                    Text("Start Normal Run")
                }.buttonStyle(.borderedProminent)
                
                NavigationLink(destination: RunningView(
                    mode: "Casual Group Run",
                    isTreadmillMode: false,
                    distance: selectedDistance
                )) {
                    Text("Casual Group Run")
                }.buttonStyle(.borderedProminent)
                
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
}

#Preview {
    HomeView()
        .environmentObject(AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser")))
}
