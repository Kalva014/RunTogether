//
//  RunTabView.swift
//  RunTogether
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
    
    var distanceConversion: [String: Double] = [
        "1 Mile": 1609.34,
        "3.1 Miles": 4989.0,
        "6.2 Miles": 9979.0,
        "13.1 Miles": 21092.0,
        "26.2 Miles": 42195.0,
        "5K": 5000.0,
        "10K": 10000.0,
        "Half Marathon (21.1K)": 21100.0,
        "Full Marathon (42.2K)": 42200.0
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    userInfoSection
                    startTimeSection
                    unitsSection
                    distanceSection
                    
                    Toggle("Treadmill Mode", isOn: $isTreadmillMode)
                        .padding(.horizontal)
                    
                    Divider()
                    
                    raceCreationSection
                    Divider()
                    
                    casualRunSection
                }
                .frame(maxWidth: .infinity)
                .padding(.top)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .overlay(waitingOverlay)
            .background(navigationLink)
            .navigationTitle("Run Together")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Sections

private extension RunTabView {
    
    var userInfoSection: some View {
        Group {
            if let user = appEnvironment.appUser {
                VStack(spacing: 5) {
                    Text("Welcome, \(user.username)!")
                        .font(.title2).bold()
                    Text("Email: \(user.email)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top)
    }
    
    var startTimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Start Time").font(.headline)
            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
        }
        .padding(.horizontal)
    }
    
    var unitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Units").font(.headline)
            Picker("Units", selection: $useMiles) {
                Text("Kilometers").tag(false)
                Text("Miles").tag(true)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
    }
    
    var distanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Distance").font(.headline)
            Picker("", selection: $selectedDistance) {
                ForEach(distanceOptions, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal)
    }
}

// MARK: - Race Creation Section

private extension RunTabView {
    
    var raceCreationSection: some View {
        VStack(spacing: 12) {
            Button("Create Race") { Task { await handleCreateRace() }}
                .buttonStyle(.borderedProminent)
            
            if let raceId = createdRaceId {
                raceIdDisplay(raceId)
            }
            
            VStack(spacing: 8) {
                TextField("Paste Race ID to Join", text: $raceIdInput)
                    .textFieldStyle(.roundedBorder)
                Button("Join Race") { Task { await handleJoinSpecific() }}
                    .buttonStyle(.borderedProminent)
            }
            
            Button("Join Random Race") { Task { await handleJoinRandom() }}
                .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }
}

// MARK: - Casual Run Button

private extension RunTabView {
    
    var casualRunSection: some View {
        Button("Start Casual Group Run") {
            Task { await handleCasualRun() }
        }
        .buttonStyle(.borderedProminent)
        .padding(.bottom, 40)
    }
}

// MARK: - Overlay

private extension RunTabView {
    
    @ViewBuilder var waitingOverlay: some View {
        if viewModel.isWaiting {
            VStack(spacing: 20) {
                HStack {
                    Button("Back") { viewModel.isWaiting = false }
                    Spacer()
                }
                .padding(.leading)
                
                Spacer()
                ProgressView().scaleEffect(1.5)
                Text(viewModel.countdownText).font(.headline)
                
                if let raceId = createdRaceId {
                    raceIdDisplay(raceId)
                }
                
                Button(createdRaceId != nil ? "Cancel Race" : "Leave Race") {
                    Task { await handleCancel() }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
        }
    }
}

// MARK: - Navigation
private extension RunTabView {
    var navigationLink: some View {
        NavigationLink(
            isActive: $navigateToRunning
        ) {
            Group {
                if let raceId = createdRaceId {
                    RunningView(
                        mode: activeMode,
                        isTreadmillMode: isTreadmillMode,
                        distance: selectedDistance,
                        useMiles: useMiles,
                        raceId: raceId
                    )
                    .environmentObject(appEnvironment)
                } else {
                    EmptyView()
                }
            }
        } label: {
            EmptyView()
        }
        .hidden()
    }
}



// MARK: - Shared UI
private extension RunTabView {
    func raceIdDisplay(_ id: UUID) -> some View {
        VStack(spacing: 5) {
            Text("Race ID:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 6) {
                Text(id.uuidString)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    UIPasteboard.general.string = id.uuidString
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

// MARK: - Actions

private extension RunTabView {
    
    @MainActor
    func handleCreateRace() async {
        activeMode = "Race"
        guard let id = await viewModel.createRace(
            appEnvironment: appEnvironment,
            mode: "Race",
            start_time: selectedTime,
            distance: distanceConversion[selectedDistance] ?? 5000
        ) else { return }
        
        print("NAVIGATING — activeMode: \(activeMode), raceId: \(String(describing: id))")

        createdRaceId = id
        UIPasteboard.general.string = id.uuidString
        await waitForStart()
    }
    
    @MainActor
    func handleJoinSpecific() async {
        activeMode = "Race"
        guard let race = await viewModel.joinSpecificRace(
            appEnvironment: appEnvironment,
            raceId: raceIdInput
        ) else { return }
        
        createdRaceId = race
        await viewModel.waitForRaceToStart(appEnvironment: appEnvironment, raceId: race.uuidString)
        navigateToRunning = true
    }
    
    @MainActor
    func handleJoinRandom() async {
        activeMode = "Race"
        guard let id = await viewModel.joinRandomRace(
            appEnvironment: appEnvironment,
            mode: "Race",
            start_time: selectedTime,
            distance: distanceConversion[selectedDistance] ?? 5000
        ) else { return }
        
        print("NAVIGATING — activeMode: \(activeMode), raceId: \(String(describing: id))")

        
        createdRaceId = id
        await waitForStart()
    }
    
    @MainActor
    func handleCasualRun() async {
        activeMode = "Casual"
        guard let id = await viewModel.joinRandomRace(
            appEnvironment: appEnvironment,
            mode: "Casual",
            start_time: selectedTime,
            distance: distanceConversion[selectedDistance] ?? 5000
        ) else { return }
        
        print("NAVIGATING — activeMode: \(activeMode), raceId: \(String(describing: id))")

        
        createdRaceId = id
        await waitForStart()
    }
    
    @MainActor
    func handleCancel() async {
        if let id = createdRaceId {
            await viewModel.cancelRace(appEnvironment: appEnvironment, raceId: id)
        }
        createdRaceId = nil
        raceIdInput = ""
        viewModel.isWaiting = false
    }
    
    @MainActor
    func waitForStart() async {
        viewModel.isWaiting = true
        await viewModel.waitUntilStartTime(startTime: selectedTime)
        viewModel.isWaiting = false
        navigateToRunning = true
    }
}


#Preview {
    RunTabView()
        .environmentObject(AppEnvironment(
            appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser"),
            supabaseConnection: SupabaseConnection()
        ))
}
