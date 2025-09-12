//
//  RaceScene.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/27/25.
//

import SpriteKit
import CoreLocation

// Basically renders the runners and logic for racing
class RaceScene: SKScene, ObservableObject {
    @Published var leaderboard: [RunnerData] = []
    @Published var playerDistance: CGFloat = 0
    var locationManager: LocationManager?
    var isTreadmillMode = false
    
    var playerRunner: SKNode!
    var otherRunners: [SKNode] = []
    var raceDistance: CGFloat = 100 // e.g., 5K in meters
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
    var otherRunnersSpeeds: [CGFloat] = [2.8, 3.5]

    var previousOpponentSpeeds: [CGFloat] = []
    var previousPlayerSpeedMultiplier: CGFloat = 0.0
    
    var lastUpdateTime: TimeInterval = 0

    // Use a boolean to track if the race is over to stop scrolling
    var isRaceOver = false
    
    var topCover: SKSpriteNode! // Add this line at the top with your other properties
    
    var backgroundTexture: SKTexture!
    var tunnelEffectNode: SKEffectNode!
    var currentPlayerSpeed: CLLocationSpeed = 0.0

    
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
        
        setupBackground()
        setupGround()
        setupPlayerRunner()
        setupOpponentRunners()
        setupFinishLine()
        
        startTime = CACurrentMediaTime()
    }
    
    private func setupBackground() {
        backgroundTexture = SKTexture(imageNamed: "StarryNight")
        let backgroundSprite = SKSpriteNode(texture: backgroundTexture)
        backgroundSprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        backgroundSprite.size = self.size
        backgroundSprite.position = CGPoint(x: 0, y: -frame.height / 4)
        backgroundSprite.zPosition = 0
        addChild(backgroundSprite)
    }
    
    private func setupGround() {
        let groundTexture = SKTexture(imageNamed: "Ground")
        let groundHeight = groundTexture.size().height
        let groundWidth = frame.width
        
        for i in 0..<4 {
            let ground = SKSpriteNode(texture: groundTexture, size: CGSize(width: groundWidth, height: groundHeight))
            ground.anchorPoint = CGPoint(x: 0.5, y: 0)
            ground.position = CGPoint(x: 0, y: -frame.height / 2 + CGFloat(i) * groundHeight)
            ground.zPosition = -1
            scrollingGroundNodes.append(ground)
            addChild(ground)
        }
    }
    
    private func setupPlayerRunner() {
        playerRunner = createRunner(name: "Ken", nationality: "UnitedStatesFlag", isPlayer: true)
        let runnerY = -frame.height / 2.5 + (frame.height * 0.2)
        playerRunner.position = CGPoint(x: 0, y: runnerY)
        addChild(playerRunner)
    }
    
    private func setupOpponentRunners() {
        let opponent1 = createRunner(name: "Bre", nationality: "CanadaFlag")
        opponent1.position = CGPoint(x: -100, y: 100)
        addChild(opponent1)
        otherRunners.append(opponent1)
        
        let opponent2 = createRunner(name: "John", nationality: "JapanFlag")
        opponent2.position = CGPoint(x: 100, y: 200)
        addChild(opponent2)
        otherRunners.append(opponent2)
        
        if let opponent1Sprite = opponent1.childNode(withName: "runnerSprite") {
            let animation = runAnimation()
            opponent1Sprite.run(animation)
        }
        
        if let opponent2Sprite = opponent2.childNode(withName: "runnerSprite") {
            let animation = runAnimation()
            opponent2Sprite.run(animation)
        }
        
        previousOpponentSpeeds = otherRunnersSpeeds
    }
    
    private func setupFinishLine() {
        let finishLineNode = SKSpriteNode(imageNamed: "FinishLineBanner")
        finishLineNode.position = CGPoint(x: 0, y: 0)
        finishLineNode.zPosition = 5
        finishLineNode.setScale(0.1)
        addChild(finishLineNode)
        finishLine = finishLineNode
    }
    
    // Ran every frame
    override func update(_ currentTime: TimeInterval) {
        guard !isRaceOver else { return }

        let deltaTime = calculateDeltaTime(currentTime)

        let speedMps: CLLocationSpeed
        if isTreadmillMode {
            // Use the manually set speed for treadmill mode
            speedMps = currentPlayerSpeed
        } else {
            // Use the GPS speed from locationManager
            speedMps = locationManager?.currentSpeed ?? 0.0
        }

        updatePlayer(speedMps: speedMps, deltaTime: deltaTime)
        scrollGround(speedMps: speedMps, deltaTime: deltaTime)
        updatePlayerAnimation(speedMps: speedMps)
        checkForRaceFinish(currentTime: currentTime)
        updateOpponents(deltaTime: deltaTime, currentTime: currentTime)
        ensurePlayerOnTop()
        
        let paceString: String?
        if isTreadmillMode {
            paceString = calculatePace(from: CGFloat(speedMps))
        } else {
            paceString = locationManager?.paceString()
        }
        
        updateLeaderboard(pace: paceString)
        updateWidgetData()
        updateFinishLine()
    }
    
    // Manually set the player's speed
    func setPlayerSpeed(to speed: CLLocationSpeed) {
        self.currentPlayerSpeed = speed
    }

    private func calculateDeltaTime(_ currentTime: TimeInterval) -> TimeInterval {
        var deltaTime = currentTime - lastUpdateTime
        if lastUpdateTime == 0 { deltaTime = 0 }
        lastUpdateTime = currentTime
        return deltaTime
    }

    private func updatePlayer(speedMps: CLLocationSpeed, deltaTime: TimeInterval) {
        if speedMps > 0 {
            let deltaDistance = CGFloat(speedMps) * CGFloat(deltaTime)
            playerDistance = min(playerDistance + deltaDistance, raceDistance)
        }
    }

    private func scrollGround(speedMps: CLLocationSpeed, deltaTime: TimeInterval) {
        if speedMps > 0, let groundHeight = scrollingGroundNodes.first?.size.height {
            for ground in scrollingGroundNodes {
                ground.position.y -= CGFloat(speedMps) * CGFloat(deltaTime) * 20
                if ground.position.y <= -frame.height / 2 - groundHeight {
                    if let topMost = scrollingGroundNodes.max(by: { $0.position.y < $1.position.y }) {
                        ground.position.y = topMost.position.y + groundHeight - 10
                    }
                }
            }
        }
    }

    private func updatePlayerAnimation(speedMps: CLLocationSpeed) {
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
    }

    private func checkForRaceFinish(currentTime: TimeInterval) {
        if playerDistance >= raceDistance && finishTimes[-1] == nil {
            finishTimes[-1] = currentTime - (startTime ?? currentTime)
            raceFinished()
        }
    }

    /// Updates all opponent runners’ positions, animations, and finish states each frame.
    /// - Parameters:
    ///   - deltaTime: The time elapsed since the last frame (in seconds).
    ///   - currentTime: The current system/game time (used to record finish times).
    private func updateOpponents(deltaTime: TimeInterval, currentTime: TimeInterval) {
        for i in 0..<otherRunners.count {
            let runnerNode = otherRunners[i]
            let runnerSprite = runnerNode.childNode(withName: "runnerSprite")!

            // 1. Update this runner’s distance traveled
            let deltaDistance = otherRunnersSpeeds[i] * CGFloat(deltaTime)
            otherRunnersCurrentDistances[i] = min(
                otherRunnersCurrentDistances[i] + deltaDistance,
                raceDistance
            )

            let runnerDistance = otherRunnersCurrentDistances[i]
            let delta = runnerDistance - playerDistance // gap compared to player

            // 2. Hide runner if finished or outside of visible range
            runnerNode.isHidden = runnerDistance >= raceDistance || delta <= -50 || delta > 500

            if !runnerNode.isHidden {
                // 3. Base Y = ground line for runners
                let baseY = -frame.height / 2.5 + (frame.height * 0.2)

                // 4. Map distance gap (0–1000m) → screen X position
                let maxVisibleDelta: CGFloat = 500   // shrink fully within 500m instead of 1000m
                let trackWidth: CGFloat = frame.width * 0.8
                let progress = min(delta / maxVisibleDelta, 1.0)
                let offsetX = progress * trackWidth - (trackWidth / 2)

                // 5. Stagger runners slightly left/right into "lanes"
                let laneSpacing: CGFloat = 80
                let laneOffset = CGFloat(i - otherRunners.count / 2) * laneSpacing

                // 6. Update runner’s screen position
                runnerNode.position = CGPoint(x: offsetX + laneOffset, y: baseY)

                // 7. Scale runner by distance gap (farther = smaller, shrinks faster now)
                let shrinkStrength: CGFloat = 1.0    // stronger scaling curve
                let scaleFactor = max(0.2, 1.0 - (delta / maxVisibleDelta) * shrinkStrength)
                runnerNode.setScale(scaleFactor)

                // 8. Update animation speed if this runner’s speed changed
                let newSpeed = otherRunnersSpeeds[i]
                if previousOpponentSpeeds[i] != newSpeed {
                    runnerSprite.removeAllActions()
                    runnerSprite.run(runAnimation(speedMultiplier: newSpeed / 3.0))
                    previousOpponentSpeeds[i] = newSpeed
                }
            }

            // 9. Record finish time if runner crosses finish line
            if runnerDistance >= raceDistance && finishTimes[i] == nil {
                finishTimes[i] = currentTime - (startTime ?? currentTime)
            }
        }
    }

    private func ensurePlayerOnTop() {
        playerRunner.zPosition = 10
        for runnerNode in otherRunners {
            runnerNode.zPosition = 5
        }
    }

    private func updateLeaderboard(pace: String?) {
        var currRunners: [RunnerData] = []

        currRunners.append(RunnerData(
            name: "Ken",
            distance: playerDistance,
            pace: pace ?? "--:--",
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
    }
    
    private func updateFinishLine() {
        if finishLine == nil {
            let finishLineNode = SKSpriteNode(imageNamed: "FinishLineBanner")
            
            finishLineNode.position = CGPoint(x: 0, y: -frame.height/4)
            
            finishLineNode.zPosition = 5
            finishLineNode.setScale(0.1)
            addChild(finishLineNode)
            finishLine = finishLineNode
        }

        if let finishLine = finishLine {
            let progress = min(playerDistance / raceDistance, 1.0)
            
            finishLine.position.y = -frame.height/4 + progress
            
            finishLine.setScale(0.1 + 1.0 * progress)
            
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
