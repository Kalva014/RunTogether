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
        guard currentSpeed > 0 else { return "--:--" }
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
    var raceDistance: CGFloat = 100 // e.g., 5K in meters
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
    var previousPlayerSpeedMultiplier: CGFloat = 0.0
    
    var lastUpdateTime: TimeInterval = 0

    // Use a boolean to track if the race is over to stop scrolling
    var isRaceOver = false
    
    var topCover: SKSpriteNode! // Add this line at the top with your other properties
    
    var backgroundTexture: SKTexture!
    var tunnelEffectNode: SKEffectNode!

    
    // Initialize runner
    func createRunner(name: String, nationality: String, isPlayer: Bool = false) -> SKNode {
        let runnerGroup = SKNode()

        // Runner sprite
        let runner = SKSpriteNode(imageNamed: "MaleRunner")
        runner.name = "runnerSprite"
        runnerGroup.addChild(runner)

        // Only add flag + name for non-player runners
        if !isPlayer {
            let labelContainer = SKNode()
            labelContainer.position = CGPoint(x: 0, y: runner.size.height / 2 + 10)

            let flagSprite = SKSpriteNode(imageNamed: nationality)
            flagSprite.size = CGSize(width: 40, height: 25)
            flagSprite.position = CGPoint(x: -30, y: 0)

            let nameLabel = SKLabelNode(fontNamed: "Avenir-Medium")
            nameLabel.text = name
            nameLabel.fontColor = .white
            nameLabel.fontSize = 14
            nameLabel.position = CGPoint(x: 20, y: -nameLabel.frame.height / 2)

            labelContainer.addChild(flagSprite)
            labelContainer.addChild(nameLabel)

            runnerGroup.addChild(labelContainer)
        }

        return runnerGroup
    }

    
    // Character run animation
    func runAnimation(speedMultiplier: CGFloat = 1.0) -> SKAction {
        let flipRight = SKAction.scaleX(to: 1, duration: 0)
        let flipLeft = SKAction.scaleX(to: -1, duration: 0)

        let frameDuration = max(0.05, 0.25 / speedMultiplier) // cap speed
        let delay = SKAction.wait(forDuration: frameDuration)

        let runSequence = SKAction.sequence([
            flipLeft,
            delay,
            flipRight,
            delay
        ])
        return .repeatForever(runSequence)
    }

    
    // Idle: no actions, just the base sprite
    func idleAnimation(sprite: SKNode) {
        sprite.removeAllActions()
    }
    
    // Calculate the runner's pace
    func calculatePace(from speedMps: CGFloat) -> String {
        guard speedMps > 0.1 else { return "--:--" }
        let paceSecondsPerKm = 1000.0 / Double(speedMps)
        let minutes = Int(paceSecondsPerKm / 60)
        let seconds = Int(paceSecondsPerKm.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }

    // Handle race completion
    func raceFinished() {
        guard !isRaceOver else { return }
        isRaceOver = true

        // Stop the player's motion immediately
        playerDistance = raceDistance
        scrollSpeed = 0
        playerRunner.childNode(withName: "runnerSprite")?.removeAllActions()

        // Optional: show "Race Complete" label
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
        
        // Create the static background.
        backgroundTexture = SKTexture(imageNamed: "StarryNight")
        let backgroundSprite = SKSpriteNode(texture: backgroundTexture)
        backgroundSprite.anchorPoint = CGPoint(x: 0.5, y: 0) // Center the anchor point
        backgroundSprite.size = self.size
        backgroundSprite.position = CGPoint(x: 0, y: -frame.height / 4)
        backgroundSprite.zPosition = 0 // Place it far in the background
        addChild(backgroundSprite)
        
        // Create 4 ground tiles.
        let groundTexture = SKTexture(imageNamed: "Ground")
        let groundHeight = groundTexture.size().height
        let groundWidth = frame.width
        
        for i in 0..<4 {
            let ground = SKSpriteNode(texture: groundTexture, size: CGSize(width: groundWidth, height: groundHeight))
            ground.anchorPoint = CGPoint(x: 0.5, y: 0)
            
            // Start them stacked from the bottom of the screen up
            ground.position = CGPoint(x: 0, y: -frame.height / 2 + CGFloat(i) * groundHeight)
            
            ground.zPosition = -1 // Place them behind the runners
            scrollingGroundNodes.append(ground)
            addChild(ground)
        }

        // Create the user's runner.
        playerRunner = createRunner(name: "Ken", nationality: "UnitedStatesFlag", isPlayer: true)
        let runnerY = -frame.height / 2.5 + (frame.height * 0.2)
        playerRunner.position = CGPoint(x: 0, y: runnerY)
        addChild(playerRunner)

        // Create dummy runners.
        let opponent1 = createRunner(name: "Bre", nationality: "CanadaFlag")
        opponent1.position = CGPoint(x: -100, y: 100)
        addChild(opponent1)
        otherRunners.append(opponent1)
        
        let opponent2 = createRunner(name: "John", nationality: "JapanFlag")
        opponent2.position = CGPoint(x: 100, y: 200)
        addChild(opponent2)
        otherRunners.append(opponent2)
        
        // Animate the opponent runners.
        if let opponent1Sprite = opponent1.childNode(withName: "runnerSprite") {
            let animation = runAnimation()
            opponent1Sprite.run(animation)
        }
        
        if let opponent2Sprite = opponent2.childNode(withName: "runnerSprite") {
            let animation = runAnimation()
            opponent2Sprite.run(animation)
        }
        
        // Initialize previous speeds to match initial speeds.
        previousOpponentSpeeds = otherRunnersSpeeds
        
        // Initialize the finish line.
        let finishLineNode = SKSpriteNode(imageNamed: "FinishLineBanner")
        finishLineNode.position = CGPoint(x: 0, y: 0)
        finishLineNode.zPosition = 5
        finishLineNode.setScale(0.1)
        addChild(finishLineNode)
        finishLine = finishLineNode

        startTime = CACurrentMediaTime()
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard let speedMps = locationManager?.currentSpeed else { return }
        guard !isRaceOver else { return }

        // Calculate deltaTime
        var deltaTime = currentTime - lastUpdateTime
        if lastUpdateTime == 0 { deltaTime = 0 }
        lastUpdateTime = currentTime

        // 1. Update player distance (speed in m/s)
        if speedMps > 0 {
            let deltaDistance = CGFloat(speedMps) * CGFloat(deltaTime)
            playerDistance = min(playerDistance + deltaDistance, raceDistance)
        }

        // 2. Move ground relative to player speed
        if speedMps > 0, let groundHeight = scrollingGroundNodes.first?.size.height {
            for ground in scrollingGroundNodes {
                ground.position.y -= CGFloat(speedMps) * CGFloat(deltaTime) * 20
                if ground.position.y <= -frame.height/2 - groundHeight {
                    if let topMost = scrollingGroundNodes.max(by: { $0.position.y < $1.position.y }) {
                        ground.position.y = topMost.position.y + groundHeight - 10
                    }
                }
            }
        }

        // 3. Update player sprite animation
        if let playerSprite = playerRunner.childNode(withName: "runnerSprite") {
            if speedMps <= 0.1 {
                playerSprite.removeAllActions()
                previousPlayerSpeedMultiplier = 0
            } else {
                let speedMultiplier = max(CGFloat(speedMps) / 3.0, 0.1)
                if abs(speedMultiplier - previousPlayerSpeedMultiplier) > 0.1 {
                    playerSprite.removeAllActions()
                    playerSprite.run(runAnimation(speedMultiplier: speedMultiplier))
                    previousPlayerSpeedMultiplier = speedMultiplier
                }
            }
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

            otherRunnersCurrentDistances[i] = min(otherRunnersCurrentDistances[i] + otherRunnersSpeeds[i], raceDistance)
            let runnerDistance = otherRunnersCurrentDistances[i]
            let delta = runnerDistance - playerDistance

            runnerNode.isHidden = runnerDistance >= raceDistance || delta <= 0 || delta > 1000
            if !runnerNode.isHidden {
                let baseY = -frame.height / 2.5 + (frame.height * 0.2)
                let offsetX = CGFloat(i - otherRunners.count / 2) * 50
                runnerNode.position = CGPoint(x: offsetX, y: baseY)
                let scaleFactor = max(0.3, 1.0 - (delta / 1000.0) * 0.7)
                runnerNode.setScale(scaleFactor)

                // Animate opponent if speed changed
                let newSpeed = otherRunnersSpeeds[i]
                if previousOpponentSpeeds[i] != newSpeed {
                    runnerSprite.removeAllActions()
                    runnerSprite.run(runAnimation(speedMultiplier: newSpeed / 4.5))
                    previousOpponentSpeeds[i] = newSpeed
                }
            }

            if runnerDistance >= raceDistance && finishTimes[i] == nil {
                finishTimes[i] = currentTime - (startTime ?? currentTime)
            }
        }

        // 6. Ensure player stays on top visually
        playerRunner.zPosition = 10
        for runnerNode in otherRunners {
            runnerNode.zPosition = 5
        }

        // 7. Update leaderboard
        let pace = locationManager?.paceString() ?? "0:00"
        var currRunners: [RunnerData] = []

        currRunners.append(RunnerData(
            name: "Ken",
            distance: playerDistance,
            pace: pace,
            finishTime: finishTimes[-1]
        ))

        for i in 0..<otherRunners.count {
            currRunners.append(RunnerData(
                name: "Opponent \(i+1)",
                distance: otherRunnersCurrentDistances[i],
                pace: calculatePace(from: otherRunnersSpeeds[i]),
                finishTime: finishTimes[i]
            ))
        }

        leaderboard = currRunners.sorted {
            if let t1 = $0.finishTime, let t2 = $1.finishTime {
                return t1 < t2
            } else if $0.finishTime != nil {
                return true
            } else if $1.finishTime != nil {
                return false
            } else {
                return $0.distance > $1.distance
            }
        }
        
        updateWidgetData()

        // 8. Initialize and update finish line
        if finishLine == nil {
            let finishLineNode = SKSpriteNode(imageNamed: "FinishLineBanner")
            
            // Start at the top of the bottom part of the black mask
            finishLineNode.position = CGPoint(x: 0, y: -frame.height/4)
            
            finishLineNode.zPosition = 5 // behind player initially
            finishLineNode.setScale(0.1) // small start scale
            addChild(finishLineNode)
            finishLine = finishLineNode
        }

        if let finishLine = finishLine {
            let progress = min(playerDistance / raceDistance, 1.0)
            
            // Start at top of bottom mask section, end just above player
            finishLine.position.y = -frame.height/4 + progress
            
            // Scale finish line as player approaches
            finishLine.setScale(0.1 + 1.0 * progress)
            
            // Z-index: player in front until crossing
            if playerDistance < raceDistance {
                finishLine.zPosition = 5
                playerRunner.zPosition = 10
            } else {
                finishLine.zPosition = 10
                playerRunner.zPosition = 9
            }
        }
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

            // Settings button and Player stats
            VStack {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Button(action: {}) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            if let speed = raceScene.locationManager?.currentSpeed {
                                Text("Pace: \(raceScene.locationManager?.paceString() ?? "--:--") min/km")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            
                            Text("Distance: \(Int(raceScene.playerDistance)) m")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            let progress = raceScene.playerDistance / raceScene.raceDistance * 100
                            Text(String(format: "Progress: %.0f%%", progress))
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.4), lineWidth: 2)
                                .background(Color.black.opacity(0.2))
                        )
                        .cornerRadius(10)
                    }
                    .padding(.top, 40)
                    .padding(.trailing, 16)
                }
                Spacer()
            }
            
            // Leaderboard
            VStack(alignment: .leading, spacing: 8) {
                Text("Leaderboard")
                    .font(.headline)
                    .foregroundColor(.yellow)
                    .padding(.leading, 16)

                ScrollView(.vertical) {
                    VStack(spacing: 4) { // Reduced spacing
                        ForEach(Array(raceScene.leaderboard.enumerated()), id: \.element.id) { index, runner in
                            HStack(spacing: 4) { // Reduced spacing
                                Text("\(index + 1)")
                                    .frame(width: 20, alignment: .leading) // Smaller width
                                    .foregroundColor(.yellow)

                                Text(runner.name)
                                    .frame(maxWidth: 60, alignment: .leading) // Smaller width
                                    .lineLimit(1) // Prevents wrapping

                                Text("\(Int(runner.distance))m")
                                    .frame(width: 45, alignment: .trailing) // Smaller width

                                if index == 0 {
                                    if let time = runner.finishTime {
                                        Text(raceScene.formatTime(time))
                                            .frame(width: 50, alignment: .trailing) // Smaller width
                                    } else {
                                        Text("\(runner.pace) min/km")
                                            .frame(width: 50, alignment: .trailing) // Smaller width
                                    }
                                } else {
                                    if let leaderTime = raceScene.leaderboard.first?.finishTime,
                                       let time = runner.finishTime {
                                        let gap = time - leaderTime
                                        Text("+\(raceScene.formatTime(gap))")
                                            .frame(width: 50, alignment: .trailing) // Smaller width
                                    } else {
                                        Text("\(runner.pace) min/km")
                                            .frame(width: 50, alignment: .trailing) // Smaller width
                                    }
                                }
                            }
                            .padding(.vertical, 4) // Reduced vertical padding
                            .padding(.horizontal, 6)
                            .background(
                                runner.finishTime != nil
                                ? Color.green.opacity(0.5)
                                : Color.black.opacity(0.4)
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .font(.system(size: 10)) // Smaller font size
                            .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxHeight: 180) // Shorter height
                .frame(width: 200) // Narrower width
            }
            .padding(.top, 50)
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            raceScene.size = CGSize(
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height
            )
            raceScene.scaleMode = .fill
            raceScene.locationManager = locationManager
        }
    }
}

#Preview {
    RunningView(mode: "Race")
        .environmentObject(AppEnvironment())
}
