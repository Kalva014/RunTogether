//
//  RunTabView.swift
//  RunTogether
//
//  Updated by ChatGPT on 10/14/25.
//
import SwiftUI

struct RunTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel = RunTabViewModel()
    
    @State private var isTreadmillMode = false
    @State private var selectedDistance: String = "5K"
    @State private var useMiles = false
    @State private var selectedTime = Date()
    @State private var raceIdInput = ""
    @State private var createdRaceId: UUID?
    
    @State private var navigateToRunning = false
    @State private var activeMode: String = "Race"
    
    var distanceOptions: [String] {
        useMiles
            ? ["1 Mile", "3.1 Miles", "6.2 Miles", "13.1 Miles", "26.2 Miles"]
            : ["5K", "10K", "Half Marathon (21.1K)", "Full Marathon (42.2K)"]
    }
    
    var distanceConversion = [
        "1 Mile": 1609.34,
        "3.1 Miles": 4989.0,
        "6.2 Miles": 9979.0,
        "13.1 Miles": 21092.0,
        "26.2 Miles": 42195.0,
        "5K": 5000.0,
        "10K": 10000.0,
        "Half Marathon (21.1K)": 21100.0,
        "Full Marathon (42.2K)": 42200.0,
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // --- User Info ---
                    if let appUser = appEnvironment.appUser {
                        VStack(spacing: 5) {
                            Text("Welcome, \(appUser.username)!")
                                .font(.title2)
                                .bold()
                            Text("Email: \(appUser.email)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top)
                    }
                    
                    // --- Start Time ---
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select Start Time")
                            .font(.headline)
                        DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                    }
                    .padding(.horizontal)
                    
                    // --- Units ---
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Units")
                            .font(.headline)
                        Picker("Units", selection: $useMiles) {
                            Text("Kilometers").tag(false)
                            Text("Miles").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    
                    // --- Distance ---
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Distance")
                            .font(.headline)
                        Picker("Distance", selection: $selectedDistance) {
                            ForEach(distanceOptions, id: \.self) { distance in
                                Text(distance)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal)
                    
                    // --- Treadmill Mode ---
                    Toggle("Treadmill Mode", isOn: $isTreadmillMode)
                        .padding(.horizontal)
                    
                    Divider().padding(.vertical)
                    
                    // --- Race Creation Section ---
                    VStack(spacing: 12) {
                        Button("Create Race") {
                            Task {
                                activeMode = "Race"
                                if let raceId = await viewModel.createRace(
                                    appEnvironment: appEnvironment,
                                    mode: "Race",
                                    start_time: selectedTime,
                                    distance: distanceConversion[selectedDistance] ?? 5000.0
                                ) {
                                    createdRaceId = raceId
                                    UIPasteboard.general.string = raceId.uuidString
                                    print("Race ID copied to clipboard: \(raceId)")
                                    
                                    await MainActor.run { viewModel.isWaiting = true }
                                    await viewModel.waitUntilStartTime(startTime: selectedTime)
                                    await MainActor.run {
                                        viewModel.isWaiting = false
                                        navigateToRunning = true
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        if let raceId = createdRaceId {
                            VStack(spacing: 5) {
                                Text("Race ID:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text(raceId.uuidString)
                                        .font(.caption2)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                    Button(action: {
                                        UIPasteboard.general.string = raceId.uuidString
                                    }) {
                                        Label("Copy", systemImage: "doc.on.doc")
                                            .labelStyle(.iconOnly)
                                    }
                                }
                            }
                        }
                        
                        VStack(spacing: 8) {
                            TextField("Paste Race ID to Join", text: $raceIdInput)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                            
                            Button("Join Race") {
                                Task {
                                    activeMode = "Race"
                                    if let joinedRace = await viewModel.joinSpecificRace(
                                        appEnvironment: appEnvironment,
                                        raceId: raceIdInput
                                    ) {
                                        await MainActor.run { viewModel.isWaiting = true }
                                        await viewModel.waitForRaceToStart(
                                            appEnvironment: appEnvironment,
                                            raceId: joinedRace.uuidString
                                        )
                                        await MainActor.run {
                                            viewModel.isWaiting = false
                                            navigateToRunning = true
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Button("Join Random Race") {
                            Task {
                                activeMode = "Race"
                                await MainActor.run { viewModel.isWaiting = true }
                                await viewModel.joinRandomRace(
                                    appEnvironment: appEnvironment,
                                    mode: "Race",
                                    start_time: selectedTime,
                                    distance: distanceConversion[selectedDistance] ?? 5000.0
                                )
                                await MainActor.run {
                                    viewModel.isWaiting = false
                                    navigateToRunning = true
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    
                    Divider().padding(.vertical)
                    
                    // --- Casual Run Section ---
                    Button("Start Casual Group Run") {
                        Task {
                            activeMode = "Casual"
                            await MainActor.run { viewModel.isWaiting = true }
                            await viewModel.joinRandomRace(
                                appEnvironment: appEnvironment,
                                mode: "Casual",
                                start_time: selectedTime,
                                distance: distanceConversion[selectedDistance] ?? 5000.0
                            )
                            await MainActor.run {
                                viewModel.isWaiting = false
                                navigateToRunning = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.top)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 10) }
            .background(Color(.systemGroupedBackground))
            
            // --- Waiting Overlay ---
            .overlay {
                if viewModel.isWaiting {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.bottom)
                        Text(viewModel.countdownText)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                }
            }
            
            // --- Navigation to RunningView ---
            .background(
                NavigationLink(isActive: $navigateToRunning) {
                    RunningView(
                        mode: activeMode,
                        isTreadmillMode: isTreadmillMode,
                        distance: selectedDistance,
                        useMiles: useMiles
                    )
                } label: { EmptyView() }
            )
            .navigationTitle("Run Together")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    RunTabView()
        .environmentObject(AppEnvironment(
            appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"),
            supabaseConnection: SupabaseConnection()
        ))
}
