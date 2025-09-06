//
//  RunningView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/27/25.
//
import SwiftUI
import SpriteKit
import CoreLocation

// For obtaining the live gps
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var currentSpeed: CLLocationSpeed = 0 // meters per second
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 1 // update every meter
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // speed in m/s, fallback to 0 if invalid
        currentSpeed = max(location.speed, 0)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func paceString() -> String {
        guard currentSpeed > 0 else { return "0:00" }
        let paceSecondsPerKm = 1000 / currentSpeed
        let minutes = Int(paceSecondsPerKm / 60)
        let seconds = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


// Basically renders the runners and logic for racing
class RaceScene: SKScene, ObservableObject {
    @Published var leaderboard: [RunnerData] = []
    var locationManager: LocationManager?
    
    var playerRunner: SKNode!
    var otherRunners: [SKNode] = []
    var raceDistance: CGFloat = 5000 // e.g., 5K in meters
    var playerDistance: CGFloat = 0
    var scrollSpeed: CGFloat = 5.0
    var finishLine: SKSpriteNode!
    
    var startTime: TimeInterval?         // The time the race started
    var finishTimes: [Int: TimeInterval] = [:] // Track finish time per runner: -1 = player, 0..N-1 = opponents
    
    // Background track nodes for looping
    var track1: SKSpriteNode!
    var track2: SKSpriteNode!
    var scrollingGroundNodes: [SKSpriteNode] = []
    
    // Initialize runners with starting distances
    var otherRunnersCurrentDistances: [CGFloat] = [50, 120] // starting distances
    var otherRunnersSpeeds: [CGFloat] = [4.5, 5.2]          // meters per frame
    
    var previousOpponentSpeeds: [CGFloat] = []

    // Use a boolean to track if the race is over to stop scrolling
    var isRaceOver = false
    
    // Initialize runner
    func createRunner(name: String, nationality: String) -> SKNode {
        // Parent group container
        let runnerGroup = SKNode()
        
        // Create and position the runner on the screen
        let runner = SKSpriteNode(imageNamed: "MaleRunner")
        runner.position = CGPoint(x: frame.midX, y: frame.midY)
        runner.name = "runnerSprite"
        runnerGroup.addChild(runner)
        
        // Add the user's flag to the runner
        let flagSprite = SKSpriteNode(imageNamed: nationality)
        flagSprite.size = CGSize(width: 40, height: 25) // Customize flag size
        flagSprite.position = CGPoint(x: 0, y: runner.size.height / 2 + 10) // Position above runner
        flagSprite.zPosition = 1 // Ensure flag is drawn on top of the runner
        runnerGroup.addChild(flagSprite)
        
        // Add the name label
        let nameLabel = SKLabelNode(fontNamed: "Avenir-Medium")
        nameLabel.text = name
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: flagSprite.position.y + flagSprite.size.height / 2 + 5) // Position above flag
        nameLabel.zPosition = 2 // Ensure label is drawn on top of everything
        runnerGroup.addChild(nameLabel)
        
        return runnerGroup
    }
    
    // Character run animation
    func runAnimation(speedMultiplier: CGFloat = 1.0) -> SKAction {
        let flipRight = SKAction.scaleX(to: 1, duration: 0)
        let flipLeft = SKAction.scaleX(to: -1, duration: 0)
        
        // Adjust delay based on speedMultiplier
        let delay = SKAction.wait(forDuration: 0.2 / speedMultiplier)
        
        let runSequence = SKAction.sequence([
            flipLeft,
            delay,
            flipRight,
            delay
        ])
        
        return .repeatForever(runSequence)
    }

    
    // Calculate the runner's pace
    func calculatePace(for distance: CGFloat) -> String {
        // Replace with real pace logic
        let minutes = Int(distance / 200) % 10
        let seconds = Int(distance) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    // Handle race completion
    func raceFinished() {
        guard !isRaceOver else { return }
        isRaceOver = true

        // Stop the player's motion immediately
        playerDistance = raceDistance
        scrollSpeed = 0
        playerRunner.childNode(withName: "runnerSprite")?.removeAllActions()

        // Create the finish line
        let newFinishLine = SKSpriteNode(imageNamed: "FinishLineBanner")
        newFinishLine.position = CGPoint(x: frame.midX, y: playerRunner.position.y - 75)
        newFinishLine.zPosition = 10
        newFinishLine.setScale(0.01)
        addChild(newFinishLine)
        finishLine = newFinishLine

        // Stop any ongoing actions
        finishLine?.removeAllActions()

        // Immediately set the target scale without interpolation
        finishLine?.setScale(1.5)

        // Show "Race Complete" label
        let label = SKLabelNode(text: "Race Complete!")
        label.fontName = "Avenir-Heavy"
        label.fontSize = 40
        label.fontColor = .yellow
        label.position = CGPoint(x: 0, y: 0)
        label.zPosition = 100
        addChild(label)
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Updating player stats each frame, save them to the widget
    func updateWidgetData() {
        let defaults = UserDefaults(suiteName: "group.com.kenneth.RunTogether")
        let playerPosition = leaderboard.firstIndex(where: { $0.name == "Ken" }) ?? 0
        let playerDistanceInt = Int(playerDistance)
        let playerPace = formatTime(finishTimes[-1] ?? CACurrentMediaTime() - (startTime ?? CACurrentMediaTime()))
        
        let widgetData: [String: Any] = [
            "distance": playerDistanceInt,
            "position": playerPosition + 1, // 1-indexed
            "pace": playerPace
        ]
        
        defaults?.set(widgetData, forKey: "CurrentRunnerData")
        defaults?.synchronize()
    }

    // This method is used to initialize the sprites and called when your game scene is ready to run
    override func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.backgroundColor = .black
        
        let groundTexture = SKTexture(imageNamed: "Ground")
        let groundHeight = groundTexture.size().height
        let groundWidth = frame.width
        
        // Create 4 ground tiles (stacked up above the screen initially)
        for i in 0..<4 {
            let ground = SKSpriteNode(texture: groundTexture, size: CGSize(width: groundWidth, height: groundHeight))
            ground.anchorPoint = CGPoint(x: 0.5, y: 0)
            
            // Start them stacked from bottom up
            ground.position = CGPoint(
                x: 0,
                y: -frame.height/2 + CGFloat(i) * groundHeight
            )
            
            ground.zPosition = -1
            scrollingGroundNodes.append(ground)
            addChild(ground)
        }
        
        // Add a black box on top of the screen as a "mask"
        let topCover = SKSpriteNode(color: .black, size: CGSize(width: frame.width, height: frame.height))
        topCover.anchorPoint = CGPoint(x: 0.5, y: 0) // anchor bottom
        // Place it at the very top of the screen
        topCover.position = CGPoint(x: 0, y: -frame.height / 4)
        topCover.zPosition = 0 // on top of everything
        addChild(topCover)
        
        // Create the user's runner
        playerRunner = createRunner(name: "Ken", nationality: "UnitedStatesFlag")
        let runnerY = -frame.height / 2.5 + (frame.height * 0.2)
        playerRunner.position = CGPoint(x: 0, y: runnerY)
        addChild(playerRunner)
        
        // Run the animation on the player's runner
        if let playerSprite = playerRunner.childNode(withName: "runnerSprite") {
            let animation = runAnimation()
            playerSprite.run(animation)
        }

        // Create some dummy runners
        let opponent1 = createRunner(name: "Bre", nationality: "CanadaFlag")
        opponent1.position = CGPoint(x: -100, y: 100)
        addChild(opponent1)
        otherRunners.append(opponent1)
        
        let opponent2 = createRunner(name: "John", nationality: "JapanFlag")
        opponent2.position = CGPoint(x: 100, y: 200)
        addChild(opponent2)
        otherRunners.append(opponent2)
        
        // Animate opponent 1
        if let opponent1Sprite = opponent1.childNode(withName: "runnerSprite") {
            let animation = runAnimation()
            opponent1Sprite.run(animation)
        }
        
        // Animate opponent 2
        if let opponent2Sprite = opponent2.childNode(withName: "runnerSprite") {
            let animation = runAnimation()
            opponent2Sprite.run(animation)
        }
        
        // Initialize previous speeds to match initial speeds
        previousOpponentSpeeds = otherRunnersSpeeds
        
        startTime = CACurrentMediaTime()
    }
    
    // Updates every frame
    override func update(_ currentTime: TimeInterval) {
        guard let speedMps = locationManager?.currentSpeed else { return }

        // 1. Update player distance only if moving
        if speedMps > 0 {
            let deltaDistance = CGFloat(speedMps / 60.0)
            playerDistance = min(playerDistance + deltaDistance, raceDistance)
        }

        // 2. Move ground only if player is moving
        if !isRaceOver && speedMps > 0 {
            guard let groundHeight = scrollingGroundNodes.first?.size.height else { return }
            for ground in scrollingGroundNodes {
                ground.position.y -= CGFloat(speedMps / 60.0)
                if ground.position.y <= -frame.height/2 - groundHeight {
                    if let topMost = scrollingGroundNodes.max(by: { $0.position.y < $1.position.y }) {
                        ground.position.y = topMost.position.y + groundHeight - 10
                    }
                }
            }
        }

        // 3. Update player sprite animation speed every frame
        if let playerSprite = playerRunner.childNode(withName: "runnerSprite") {
            let speedMultiplier = max(CGFloat(speedMps), 0.1)
            playerSprite.removeAllActions()
            playerSprite.run(runAnimation(speedMultiplier: speedMultiplier))
            playerSprite.position = CGPoint(x: 0, y: 0) // Keep in place
        }

        // 4. Check for race finish
        if playerDistance >= raceDistance && finishTimes[-1] == nil {
            finishTimes[-1] = currentTime - (startTime ?? currentTime)
            raceFinished()
        }

        // 5. Update opponents
        for i in 0..<otherRunners.count {
            let runnerNode = otherRunners[i]
            let runnerSprite = runnerNode.childNode(withName: "runnerSprite")!

            // Update distance
            otherRunnersCurrentDistances[i] = min(otherRunnersCurrentDistances[i] + otherRunnersSpeeds[i], raceDistance)
            let runnerDistance = otherRunnersCurrentDistances[i]
            let delta = runnerDistance - playerDistance

            if runnerDistance >= raceDistance || delta <= 0 || delta > 1000 {
                runnerNode.isHidden = true
            } else {
                runnerNode.isHidden = false
                let baseY = -frame.height / 2.5 + (frame.height * 0.2)
                let offsetX = CGFloat(i - otherRunners.count / 2) * 50
                runnerNode.position = CGPoint(x: offsetX, y: baseY)
                let scaleFactor = max(0.3, 1.0 - (delta / 1000.0) * 0.7)
                runnerNode.setScale(scaleFactor)

                // Animate opponent only if speed changed
                let newSpeed = otherRunnersSpeeds[i]
                if previousOpponentSpeeds[i] != newSpeed {
                    runnerSprite.removeAllActions()
                    let speedMultiplier = newSpeed / 4.5
                    runnerSprite.run(runAnimation(speedMultiplier: speedMultiplier))
                    previousOpponentSpeeds[i] = newSpeed
                }
            }
        }
        
        // Ensure player stays on top visually
        playerRunner.zPosition = 10
        for runnerNode in otherRunners {
            runnerNode.zPosition = 5
        }

        // 6. Update leaderboard
        let pace = locationManager?.paceString() ?? "0:00"
        var currRunners: [RunnerData] = []
        currRunners.append(RunnerData(name: "Ken", distance: playerDistance, pace: pace))
        for i in 0..<otherRunners.count {
            currRunners.append(RunnerData(
                name: "Opponent \(i+1)",
                distance: otherRunnersCurrentDistances[i],
                pace: calculatePace(for: otherRunnersCurrentDistances[i])
            ))
        }
        leaderboard = currRunners.sorted(by: { $0.distance > $1.distance })

        // 7. Update widget
        updateWidgetData()
    }

}

// Basically renders the runners and the logic for the casual run club
class RunClubScene: SKScene {
    
}

struct RunningView: View {
    let mode: String
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var raceScene = RaceScene()
    
    var body: some View {
        ZStack {
            SpriteView(scene: raceScene)

            // Settings button
            VStack {
                HStack {
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .padding(.leading, 16)
                            .padding(.top, 40)
                    }
                    Spacer()
                }
                Spacer()
            }

            // Leaderboard
            VStack(alignment: .trailing, spacing: 8) {
                Text("Leaderboard")
                    .font(.headline)
                    .foregroundColor(.yellow)
                
                ScrollView(.vertical) {
                    VStack(spacing: 6) {
                        ForEach(Array(raceScene.leaderboard.enumerated()), id: \.element.id) { index, runner in
                            HStack {
                                // Position number
                                Text("\(index + 1)")
                                    .frame(width: 24, alignment: .leading)
                                    .foregroundColor(.yellow)

                                // Runner name
                                Text(runner.name)
                                    .frame(maxWidth: 80, alignment: .leading)

                                // Distance
                                Text("\(Int(runner.distance))m")
                                    .frame(width: 60, alignment: .trailing)

                                // Pace
                                Text(runner.pace)
                                    .frame(width: 50, alignment: .trailing)
                            }
                            .padding(6)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .font(.caption)
                            .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxHeight: 300) // Limit height so it scrolls if content exceeds this
            }
            .padding(.top, 50)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            raceScene.size = CGSize(
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height
            )
            raceScene.scaleMode = .fill
            
            raceScene.locationManager = locationManager  // <-- important
        }
    }
}

#Preview {
    RunningView(mode: "Race")
        .environmentObject(AppEnvironment())
}
