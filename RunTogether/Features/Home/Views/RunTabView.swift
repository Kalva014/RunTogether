//
//  RunTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/22/25.
//

import SwiftUI

struct RunTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: RunTabViewModel
    @Environment(\.dismiss) var dismiss
    @State var isSignedOut: Bool = false
    @State private var isTreadmillMode: Bool = false
    @State private var selectedDistance: String = "5K" // Default 5k
    @State private var useMiles: Bool = false
    
    var distanceOptions: [String] {
        if useMiles {
            return ["1 Mile", "3.1 Miles", "6.2 Miles", "13.1 Miles", "26.2 Miles"]
        } else {
            return ["5K", "10K", "Half Marathon(21.1K)", "Full Marathon(42.2K)"]
        }
    }
    
    
    init() {
        _viewModel = StateObject(wrappedValue: RunTabViewModel())
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
                
                // Unit Picker
                Picker("Units", selection: $useMiles) {
                    Text("Kilometers").tag(false)
                    Text("Miles").tag(true)
                }
                .pickerStyle(.segmented)
                .padding()
                .frame(width: 300)
                .onChange(of: useMiles) { _, newValue in
                    if let first = distanceOptions.first {
                        selectedDistance = first
                    }
                }
                
                // Distance Picker
                HStack {
                    Text("Distance")
                        .font(.headline)
                        .padding()
                    Picker("Distance", selection: $selectedDistance) {
                        ForEach(distanceOptions, id: \.self) { distance in
                            Text(distance)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                }
                
                Toggle("Treadmill Mode", isOn: $isTreadmillMode)
                    .font(.headline)
                    .padding()
                    .frame(width: 250)
                
                NavigationLink(destination: RunningView(
                    mode: "Race",
                    isTreadmillMode: isTreadmillMode,
                    distance: selectedDistance,
                    useMiles: useMiles
                )) {
                    Text("Race")
                }.buttonStyle(.borderedProminent)
                
                NavigationLink(destination: RunningView(
                    mode: "Casual",
                    isTreadmillMode: false,
                    distance: selectedDistance,
                    useMiles: useMiles
                )) {
                    Text("Casual Group Run")
                }.buttonStyle(.borderedProminent)
            }
            .padding()
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RunTabView()
        .environmentObject(AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"), supabaseConnection: SupabaseConnection()))
}
