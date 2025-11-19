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
    @State private var showStartOptions = false
    
    @State private var showRaceDisabledTooltip = false
    
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
    
    // Helper function to convert distance in meters back to string format
    private func getDistanceString(from meters: Double, useMiles: Bool) -> String {
        let tolerance: Double = 50.0 // Allow 50m tolerance for matching
        
        if useMiles {
            let mileDistances: [(String, Double)] = [
                ("1 Mile", 1609.34),
                ("3.1 Miles", 4989.0),
                ("6.2 Miles", 9979.0),
                ("13.1 Miles", 21092.0),
                ("26.2 Miles", 42195.0)
            ]
            
            for (name, distance) in mileDistances {
                if abs(meters - distance) <= tolerance {
                    return name
                }
            }
        } else {
            let kmDistances: [(String, Double)] = [
                ("5K", 5000.0),
                ("10K", 10000.0),
                ("Half Marathon (21.1K)", 21100.0),
                ("Full Marathon (42.2K)", 42200.0)
            ]
            
            for (name, distance) in kmDistances {
                if abs(meters - distance) <= tolerance {
                    return name
                }
            }
        }
        
        // Fallback to default if no match found
        return useMiles ? "3.1 Miles" : "5K"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            heroSection
                            distanceSelector
                            treadmillSettingsSection
                            guidedRunsSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
                
                if viewModel.isWaiting {
                    waitingOverlay
                }
                
                if showStartOptions {
                    startOptionsSheet
                }
                
                if showRaceDisabledTooltip {
                    raceTooltip
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $navigateToRunning) {
                if let raceId = createdRaceId {
                    RunningView(
                        mode: activeMode,
                        isTreadmillMode: isTreadmillMode,
                        distance: selectedDistance,
                        useMiles: useMiles,
                        raceId: raceId
                    )
                    .environmentObject(appEnvironment)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "figure.run")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Hero
    
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
            
            Text("Start a Run")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }
    
    // MARK: - Distance Selector
    
    private var distanceSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distance")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(distanceOptions, id: \.self) { distance in
                        Button(action: {
                            selectedDistance = distance
                        }) {
                            Text(distance)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(selectedDistance == distance ? .black : .white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(selectedDistance == distance ? Color.orange : Color.white.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Treadmill & Miles Switches
    
    private var treadmillSettingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Treadmill Mode")
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $isTreadmillMode)
                    .labelsHidden()
                    .tint(.orange)
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            HStack {
                Text("Use Miles")
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $useMiles)
                    .labelsHidden()
                    .tint(.orange)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Guided Plans
    
    private var guidedRunsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Guided Plans")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // RACE MODE CARD — disabled if treadmill on
            guidedRunCard(
                title: "Race Mode",
                subtitle: "Compete with others",
                icon: "flag.checkered.2.crossed",
                color: .orange,
                disabled: isTreadmillMode
            ) {
                if isTreadmillMode {
                    showRaceDisabledTooltip = true
                } else {
                    activeMode = "Race"
                    showStartOptions = true
                }
            }
            
            // CASUAL RUN CARD — always available
            guidedRunCard(
                title: "Casual Run",
                subtitle: "Run at your pace",
                icon: "figure.walk",
                color: .blue
            ) {
                activeMode = "Casual"
                showStartOptions = true
            }
            
            // Join by ID
            VStack(alignment: .leading, spacing: 12) {
                Text("Join A Run by ID")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    TextField("Paste Race ID", text: $raceIdInput)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        Task { await handleJoinSpecific() }
                    }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                    }
                    .disabled(raceIdInput.isEmpty)
                    .opacity(raceIdInput.isEmpty ? 0.5 : 1)
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Guided Run Card
    
    private func guidedRunCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(color.opacity(disabled ? 0.3 : 1))
                        
                        Text(title)
                            .font(.headline)
                            .foregroundColor(disabled ? .gray : .white)
                    }
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(disabled ? 0.3 : 1))
            }
            .padding(20)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
        }
        .disabled(disabled)
    }
    
    // MARK: - Tooltip
    
    private var raceTooltip: some View {
        VStack {
            Spacer()
            Text("Race Mode is disabled in Treadmill Mode")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.red.opacity(0.9))
                .cornerRadius(12)
                .padding(.bottom, 50)
                .transition(.opacity)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showRaceDisabledTooltip = false }
            }
        }
    }
    
    // MARK: - Start Options Sheet
    
    private var startOptionsSheet: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    showStartOptions = false
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                    
                    Text("Start Your Run")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Start Time
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start Time")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                    }
                    .padding(.vertical)
                    
                    VStack(spacing: 12) {
                        
                        // =========== RACE OPTIONS ============
                        if activeMode == "Race" {
                            Button(action: {
                                Task { await handleCreateRace() }
                            }) {
                                Text("Create New Race")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.orange)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                Task { await handleJoinRandom() }
                            }) {
                                Text("Join Random Race")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(12)
                            }
                        }
                        
                        // =========== CASUAL OPTIONS ============
                        else {
                            Button(action: {
                                Task { await handleCreateCasualRun() }
                            }) {
                                Text("Create Casual Run")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                Task { await handleJoinRandomCasual() }
                            }) {
                                Text("Join Random Run")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(12)
                            }
                        }
                        
                        // Cancel
                        Button(action: { showStartOptions = false }) {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
                .background(Color(white: 0.15))
                .cornerRadius(20, corners: [.topLeft, .topRight])
            }
        }
        .transition(.move(edge: .bottom))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showStartOptions)
    }
    
    // MARK: - Waiting Overlay
    
    private var waitingOverlay: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.orange)
                    
                    Text(viewModel.countdownText)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Run starts soon...")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                if let raceId = createdRaceId {
                    VStack(spacing: 12) {
                        Text("Run ID")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text(raceId.uuidString)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Button(action: {
                                UIPasteboard.general.string = raceId.uuidString
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.orange)
                            }

                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                Button(action: {
                    Task { await handleCancel() }
                }) {
                    Text("Cancel Run")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
        }
    }
    
    // MARK: - Backend Actions
    
    @MainActor
    private func handleCreateRace() async {
        showStartOptions = false
        activeMode = "Race"
        guard let id = await viewModel.createRace(
            appEnvironment: appEnvironment,
            mode: "Race",
            start_time: selectedTime,
            distance: distanceConversion[selectedDistance] ?? 5000,
            useMiles: useMiles
        ) else { return }
        
        createdRaceId = id
        UIPasteboard.general.string = id.uuidString
        await waitForStart()
    }
    
    @MainActor
    private func handleCreateCasualRun() async {
        showStartOptions = false
        activeMode = "Casual"
        guard let id = await viewModel.createRace(
            appEnvironment: appEnvironment,
            mode: "Casual",
            start_time: selectedTime,
            distance: distanceConversion[selectedDistance] ?? 5000,
            useMiles: useMiles
        ) else { return }
        
        createdRaceId = id
        await waitForStart()
    }
    
    @MainActor
    private func handleJoinSpecific() async {
        showStartOptions = false
        guard let result = await viewModel.joinSpecificRace(
            appEnvironment: appEnvironment,
            raceId: raceIdInput
        ) else { return }
        
        // Sync race settings (except treadmill mode)
        let race = result.race
        selectedDistance = getDistanceString(from: race.distance, useMiles: race.use_miles)
        useMiles = race.use_miles
        // Note: isTreadmillMode is NOT synced as per user requirements
        
        createdRaceId = result.raceId
        await viewModel.waitForRaceToStart(appEnvironment: appEnvironment, raceId: result.raceId.uuidString)
        navigateToRunning = true
    }
    
    @MainActor
    private func handleJoinRandom() async {
        showStartOptions = false
        activeMode = "Race"
        guard let id = await viewModel.joinRandomRace(
            appEnvironment: appEnvironment,
            mode: "Race",
            start_time: selectedTime,
            distance: distanceConversion[selectedDistance] ?? 5000,
            useMiles: useMiles
        ) else { return }

        createdRaceId = id
        await waitForStart()
    }
    
    @MainActor
    private func handleJoinRandomCasual() async {
        showStartOptions = false
        activeMode = "Casual"
        guard let id = await viewModel.joinRandomRace(
            appEnvironment: appEnvironment,
            mode: "Casual",
            start_time: selectedTime,
            distance: distanceConversion[selectedDistance] ?? 5000,
            useMiles: useMiles
        ) else { return }

        createdRaceId = id
        await waitForStart()
    }
    
    @MainActor
    private func handleCancel() async {
        if let id = createdRaceId {
            await viewModel.cancelRace(appEnvironment: appEnvironment, raceId: id)
        }
        createdRaceId = nil
        raceIdInput = ""
        viewModel.isWaiting = false
    }
    
    @MainActor
    private func waitForStart() async {
        viewModel.isWaiting = true
        await viewModel.waitUntilStartTime(startTime: selectedTime)
        viewModel.isWaiting = false
        navigateToRunning = true
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
