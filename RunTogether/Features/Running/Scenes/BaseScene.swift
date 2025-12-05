//
//  BaseRunningScene.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/12/25.
//

import Foundation
import SpriteKit
import CoreLocation
import Combine

/// A shared base class for RaceScene and CasualScene.
/// Holds common state and behavior for all running scenes.
class BaseRunningScene: SKScene, ObservableObject {
    
    // MARK: - Published Properties
    @Published var leaderboard: [RunnerData] = []
    @Published var playerDistance: CGFloat = 0.0
    
    // MARK: - Shared State
    var locationManager: LocationManager?
    var isTreadmillMode: Bool = false
    var raceDistance: CGFloat = 5000.0 // Default 5K
    var currentPlayerSpeed: CLLocationSpeed = 0.0
    var useMiles: Bool = true
    var appEnvironment: AppEnvironment?
    
    // MARK: - Scene Objects
    var playerRunner: SKNode!
    var otherRunners: [SKNode] = []
    var finishLine: SKSpriteNode!
    var scrollingGroundNodes: [SKSpriteNode] = []
    
    // MARK: - Animation & Timing
    var startTime: TimeInterval?
    var finishTimes: [Int: TimeInterval] = [:] // -1 = player, 0..N-1 = opponents
    var lastUpdateTime: TimeInterval = 0
    @Published var isRaceOver = false
    
    // MARK: - Opponent State
    var otherRunnersCurrentDistances: [CGFloat] = [] // starting distances
    var otherRunnersSpeeds: [Double] = [] // speeds
    var otherRunnersNames: [String] = []
    var previousOpponentSpeeds: [Double] = []
    var previousPlayerSpeedMultiplier: CGFloat = 0.0
    var previousOpponentPositions: [CGFloat] = [] // Track previous positions for passing detection
    var lastPassingSoundTime: TimeInterval = 0 // Throttle passing sounds
    
    // MARK: - Visual Elements
    var backgroundTexture: SKTexture!
    
    // MARK: - Combine
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Realtime Multiplayer State
    var realtimeOpponents: [UUID: RealtimeOpponentData] = [:] // Track all opponents by userId
    var isRealtimeEnabled: Bool = false
    var currentRaceId: UUID? = nil // Store current race ID for database updates

    struct RealtimeOpponentData {
        let userId: UUID
        let username: String
        var distance: Double
        var paceMinutes: Double // pace in minutes per unit (km or mi)
        var speedMps: Double // speed in meters per second
        var lastUpdateTime: Date
        var spriteUrl: String? // URL to user's selected sprite
        var country: String? // User's country for flag emoji
        
        // Check if data is stale (no update in 30 seconds)
        // Increased timeout to avoid removing finished runners too quickly
        var isStale: Bool {
            Date().timeIntervalSince(lastUpdateTime) > 30
        }
        
        // Convert pace to formatted string
        func paceString() -> String {
            let minutes = Int(paceMinutes)
            let seconds = Int((paceMinutes * 60).truncatingRemainder(dividingBy: 60))
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // Store custom sprite textures for animation
    private var customSpriteTextures: [String: SKTexture] = [:]
    
    // MARK: - Lifecycle
    override init(size: CGSize) {
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.backgroundColor = .black
        
        setupBackground()
        setupGround()
        setupPlayerRunner()
//        setupOpponentRunners()
        setupFinishLine()
        
        startTime = CACurrentMediaTime()
        
        // Play race start sound
        if let appEnvironment = appEnvironment {
            Task { @MainActor in
                appEnvironment.soundManager.playRaceStart()
            }
        }
    }
    
    // MARK: - Setup Methods
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
        // Load player's sprite and country from profile first, then create runner
        if let appEnvironment = appEnvironment {
            Task { @MainActor in
                var spriteUrl: String? = nil
                var country: String? = nil
                
                do {
                    if let profile = try await appEnvironment.supabaseConnection.getProfile() {
                        spriteUrl = profile.selected_sprite_url
                        country = profile.country
                        if let url = spriteUrl, !url.isEmpty {
                            print("🎮 Preloading player sprite from: \(url)")
                            // Preload the texture into cache
                            _ = await SpriteManager.shared.loadSpriteTexture(from: url)
                        }
                    }
                } catch {
                    print("❌ Error loading player profile: \(error)")
                }
                
                // Now create player runner with the sprite URL and country (will use cached texture if available)
                playerRunner = createRunner(name: "You", nationality: country ?? "", isPlayer: true, spriteUrl: spriteUrl)
                let runnerY = -frame.height / 2.5 + (frame.height * 0.2)
                playerRunner.position = CGPoint(x: 0, y: runnerY)
                addChild(playerRunner)
                
                // Store custom texture for animation if we have one
                if let url = spriteUrl, !url.isEmpty {
                    if let texture = await SpriteManager.shared.loadSpriteTexture(from: url) {
                        self.customSpriteTextures["player"] = texture
                        print("✅ Player sprite loaded and cached")
                    }
                }
            }
        } else {
            // No app environment, create with default sprite
            playerRunner = createRunner(name: "You", nationality: "", isPlayer: true, spriteUrl: nil)
            let runnerY = -frame.height / 2.5 + (frame.height * 0.2)
            playerRunner.position = CGPoint(x: 0, y: runnerY)
            addChild(playerRunner)
        }
    }
//    
//    private func setupOpponentRunners() {
//        let opponent1 = createRunner(name: "Bre", nationality: "CanadaFlag")
//        otherRunnersNames.append("Bre")
//        opponent1.position = CGPoint(x: -100, y: 100)
//        addChild(opponent1)
//        otherRunners.append(opponent1)
//        
//        let opponent2 = createRunner(name: "John", nationality: "JapanFlag")
//        otherRunnersNames.append("John")
//        opponent2.position = CGPoint(x: 100, y: 200)
//        addChild(opponent2)
//        otherRunners.append(opponent2)
//        
//        if let opponent1Sprite = opponent1.childNode(withName: "runnerSprite") {
//            let animation = runAnimation()
//            opponent1Sprite.run(animation)
//        }
//        
//        if let opponent2Sprite = opponent2.childNode(withName: "runnerSprite") {
//            let animation = runAnimation()
//            opponent2Sprite.run(animation)
//        }
//        
//        previousOpponentSpeeds = otherRunnersSpeeds
//    }
    
    private func setupFinishLine() {
        let finishLineNode = SKSpriteNode(imageNamed: "FinishLineBannerRed")
        finishLineNode.anchorPoint = CGPoint(x: 0.5, y: 0)
        finishLineNode.position = CGPoint(x: 0, y: -frame.height / 4)
        finishLineNode.zPosition = 5
        finishLineNode.setScale(0.1)
        addChild(finishLineNode)
        finishLine = finishLineNode
    }
    
    // MARK: - Runner Creation & Animation
    private func createRunner(name: String, nationality: String, isPlayer: Bool = false, spriteUrl: String? = nil) -> SKNode {
        let runnerGroup = SKNode()

        // Runner sprite - use default for now, will be updated asynchronously
        let runner = SKSpriteNode(imageNamed: "MaleRunner")
        let defaultSize = runner.size // Store the default size
        runner.name = "runnerSprite"
        runnerGroup.addChild(runner)
        
        // Load custom sprite if URL provided
        if let spriteUrl = spriteUrl, !spriteUrl.isEmpty {
            let nodeId = isPlayer ? "player" : name
            print("🎨 Loading sprite for \(nodeId) from: \(spriteUrl)")
            
            Task { @MainActor in
                do {
                    if let texture = await SpriteManager.shared.loadSpriteTexture(from: spriteUrl) {
                        // Verify the runner still exists before updating
                        guard runner.parent != nil else {
                            print("⚠️ Runner node removed before sprite loaded for \(nodeId)")
                            return
                        }
                        
                        runner.texture = texture
                        // Maintain consistent size with default sprite
                        runner.size = defaultSize
                        
                        // Store the custom texture for animation
                        self.customSpriteTextures[nodeId] = texture
                        print("✅ Stored custom texture for: \(nodeId)")
                    } else {
                        print("❌ Failed to load texture for \(nodeId)")
                    }
                } catch {
                    print("❌ Error loading sprite for \(nodeId): \(error)")
                }
            }
        } else {
            let nodeId = isPlayer ? "player" : name
            print("ℹ️ No custom sprite URL for \(nodeId), using default")
        }

        // Only add name label for non-player runners
        if !isPlayer {
            let nameLabel = SKLabelNode(fontNamed: "Avenir-Medium")
            nameLabel.text = name
            nameLabel.fontColor = .white
            nameLabel.fontSize = 14
            nameLabel.position = CGPoint(x: 0, y: runner.size.height / 2 + 10)
            nameLabel.verticalAlignmentMode = .bottom

            runnerGroup.addChild(nameLabel)
        }

        return runnerGroup
    }
    
    func runAnimation(speedMultiplier: CGFloat = 1.0, customTexture: SKTexture? = nil) -> SKAction {
        // 1. Load textures - use custom texture if provided, otherwise use default
//        let standFrame = SKTexture(imageNamed: "MaleRunnerStanding")
//        let runFrame = SKTexture(imageNamed: "MaleRunner")
        let sprintingFrame = customTexture ?? SKTexture(imageNamed: "MaleRunerSprinting")

        // 2. Create the necessary actions
        let flipRight = SKAction.scaleX(to: 1, duration: 0)
        let flipLeft = SKAction.scaleX(to: -1, duration: 0)

        let frameDuration = max(0.05, 0.25 / speedMultiplier)
        let delay = SKAction.wait(forDuration: frameDuration)

        // 3. Create actions to change the sprite's texture
//        let setRunFrame = SKAction.setTexture(runFrame)
//        let setStandFrame = SKAction.setTexture(standFrame)
        let setSprintFrame = SKAction.setTexture(sprintingFrame)

        // 4. Combine all the actions into a sequence
        let runSequence = SKAction.sequence([
            // Run frame facing left
            flipLeft,
//            setRunFrame,
//            delay,
//            
            setSprintFrame,
            delay,
            
//            setRunFrame,
//            delay,
//            
//            // Stand frame
//            setStandFrame,
//            delay,

            // Run frame facing right
            flipRight,
//            setRunFrame,
//            delay,
//            
            setSprintFrame,
            delay,
            
//            setRunFrame,
//            delay,
//
//            // Stand frame again
//            setStandFrame,
//            delay
        ])

        return .repeatForever(runSequence)
    }
    
    func idleAnimation(sprite: SKNode) {
        sprite.removeAllActions()
    }
    
    // MARK: - Game Loop
    override func update(_ currentTime: TimeInterval) {
        guard !isRaceOver else { return }

        let deltaTime = calculateDeltaTime(currentTime)

        let speedMps: CLLocationSpeed
        if isTreadmillMode {
            speedMps = currentPlayerSpeed
        } else {
            speedMps = locationManager?.currentSpeed ?? 0.0
        }

        updatePlayer(speedMps: speedMps, deltaTime: deltaTime)
        scrollGround(speedMps: speedMps, deltaTime: deltaTime)
        updatePlayerAnimation(speedMps: speedMps)
        checkForRaceFinish(currentTime: currentTime)
        
//        updateOpponents(deltaTime: deltaTime, currentTime: currentTime)
        // In the update() method, replace the opponent update section with:
        if isRealtimeEnabled {
            updateOpponentsRealtime(deltaTime: deltaTime, currentTime: currentTime)
        } else {
            updateOpponents(deltaTime: deltaTime, currentTime: currentTime)
        }
        
        ensurePlayerOnTop()
        
        let paceString: String?
        if isTreadmillMode {
            paceString = calculatePace(from: CGFloat(speedMps), useMiles: useMiles)
        } else {
            paceString = locationManager?.paceString(useMiles: useMiles)
        }
        
        updateLeaderboard(pace: paceString)
        updateWidgetData()
        updateFinishLine()
    }
    
    // MARK: - Update Methods
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
        guard let playerRunner = playerRunner,
              let playerSprite = playerRunner.childNode(withName: "runnerSprite") else {
            return
        }
        
        if speedMps <= 0.1 {
            playerSprite.removeAllActions()
            previousPlayerSpeedMultiplier = 0
        } else {
            let speedMultiplier = max(CGFloat(speedMps) / 3.0, 0.1)
            if abs(speedMultiplier - previousPlayerSpeedMultiplier) > 0.1 {
                playerSprite.removeAllActions()
                let customTexture = customSpriteTextures["player"]
                playerSprite.run(runAnimation(speedMultiplier: speedMultiplier, customTexture: customTexture))
                previousPlayerSpeedMultiplier = speedMultiplier
            }
        }
    }

    private func checkForRaceFinish(currentTime: TimeInterval) {
        if playerDistance >= raceDistance && finishTimes[-1] == nil {
            finishTimes[-1] = currentTime - (startTime ?? currentTime)
            raceFinished()
        }
    }

    private func updateOpponents(deltaTime: TimeInterval, currentTime: TimeInterval) {
        // Initialize previous positions array if needed
        if previousOpponentPositions.count != otherRunners.count {
            previousOpponentPositions = otherRunnersCurrentDistances
        }
        
        for i in 0..<otherRunners.count {
            let runnerNode = otherRunners[i]
            let runnerSprite = runnerNode.childNode(withName: "runnerSprite")!

            // 1. Update this runner's distance traveled
            let deltaDistance = otherRunnersSpeeds[i] * CGFloat(deltaTime)
            otherRunnersCurrentDistances[i] = min(
                otherRunnersCurrentDistances[i] + deltaDistance,
                raceDistance
            )

            let runnerDistance = otherRunnersCurrentDistances[i]
            let delta = runnerDistance - playerDistance // gap compared to player
            
            // Detect passing: Check if player passed this opponent or got passed
            let previousDelta = previousOpponentPositions[i] - playerDistance
            // If the sign changed (was ahead, now behind or vice versa) and we're close
            if abs(delta) < 10 && abs(previousDelta) < 10 && 
               (delta > 0 && previousDelta <= 0 || delta < 0 && previousDelta >= 0) &&
               currentTime - lastPassingSoundTime > 1.0 { // Throttle to once per second
                // Play passing sound
                if let appEnvironment = appEnvironment {
                    Task { @MainActor in
                        appEnvironment.soundManager.playRunnerPassing()
                    }
                }
                lastPassingSoundTime = currentTime
            }

            // 2. Hide runner if finished or outside of visible range
            runnerNode.isHidden = runnerDistance >= raceDistance || delta <= -50 || delta > 500

            if !runnerNode.isHidden {
                // 3. Base Y = ground line for runners
                let baseY = -frame.height / 2.5 + (frame.height * 0.2)

                // 4. Map distance gap → screen X position (converge to center)
                let maxVisibleDelta: CGFloat = 500
                let progress = min(delta / maxVisibleDelta, 1.0)
                
                // 5. Stagger runners slightly left/right into "lanes"
                let laneSpacing: CGFloat = 150
                let laneOffset = CGFloat(i - otherRunners.count / 2) * laneSpacing
                
                // 6. Converge towards center as they get further ahead
                // Close runners: spread out in lanes, Far runners: converge to center
                let convergeFactor = progress // 0 = at player position, 1 = far ahead
                let offsetX = laneOffset * (1.0 - convergeFactor) // Reduce lane offset as they get further

                // 7. Update runner's screen position
                runnerNode.position = CGPoint(x: offsetX, y: baseY)

                // 8. Scale runner by distance gap (farther = smaller)
                let shrinkStrength: CGFloat = 1.0
                let scaleFactor = max(0.2, 1.0 - (delta / maxVisibleDelta) * shrinkStrength)
                runnerNode.setScale(scaleFactor)

                // 9. Update animation speed if this runner's speed changed
                let newSpeed = otherRunnersSpeeds[i]
                if previousOpponentSpeeds[i] != newSpeed {
                    runnerSprite.removeAllActions()
                    
                    // Only animate if the runner is actually moving
                    if newSpeed > 0.1 {
                        let opponentName = otherRunnersNames[i]
                        let customTexture = customSpriteTextures[opponentName]
                        runnerSprite.run(runAnimation(speedMultiplier: newSpeed / 3.0, customTexture: customTexture))
                    }
                    // If speed is 0 or very low, leave sprite in idle state (no animation)
                    
                    previousOpponentSpeeds[i] = newSpeed
                }
            }
            
            // Update previous position for next frame
            previousOpponentPositions[i] = runnerDistance

            // 10. Record finish time if runner crosses finish line
            if runnerDistance >= raceDistance && finishTimes[i] == nil {
                finishTimes[i] = currentTime - (startTime ?? currentTime)
            }
        }
    }

    private func ensurePlayerOnTop() {
        guard let playerRunner = playerRunner else { return }
        playerRunner.zPosition = 10
        for runnerNode in otherRunners {
            runnerNode.zPosition = 5
        }
    }
    
    private func updateFinishLine() {
        guard let finishLine = finishLine else { return }
        finishLine.anchorPoint = CGPoint(x: 0.5, y: 0)

        // Calculate progress (0 = start, 1 = finish)
        let progress = min(playerDistance / raceDistance, 1.0)

        // Scale between min and max
        let minScale: CGFloat = 0.1
        let maxScale: CGFloat = 1.15 // ADJUST NUMBER TO SCALE FINISH LINE SIZE AS IT GROWS
        let targetScale = minScale + (maxScale - minScale) * progress

        // Move finish line down slightly as it grows
        let startY = -frame.height / 4
        let endY = startY - 75 * progress // Adjust the "50" to control downward shift
        let targetY = startY + (endY - startY)

        // Create actions
        let scaleAction = SKAction.scale(to: targetScale, duration: 0.05)
        let moveAction = SKAction.moveTo(y: targetY, duration: 0.05)
        let groupAction = SKAction.group([scaleAction, moveAction])

        finishLine.run(groupAction)

        // Z-order
        finishLine.zPosition = progress < 1.0 ? 5 : 10
        if let playerRunner = playerRunner {
            playerRunner.zPosition = 10
        }
        for i in 0..<otherRunners.count {
            otherRunners[i].zPosition = otherRunnersCurrentDistances[i] < raceDistance ? 9 : 8
        }
    }
    
    // MARK: - Race Management
    func raceFinished() {
        guard !isRaceOver else { return }
        print("🏁 Race finished! Setting isRaceOver = true")
        isRaceOver = true

        // Play race finish sound
        if let appEnvironment = appEnvironment {
            Task { @MainActor in
                appEnvironment.soundManager.playRaceFinish()
            }
        }

        // Stop the player's motion immediately
        playerDistance = raceDistance
        if let playerRunner = playerRunner {
            playerRunner.childNode(withName: "runnerSprite")?.removeAllActions()
        }

        // Optional: show "Race Complete" label (positioned higher to not block UI)
        let label = SKLabelNode(text: "Race Complete!")
        label.fontName = "Avenir-Heavy"
        label.fontSize = 40
        label.fontColor = .yellow
        label.position = CGPoint(x: 0, y: frame.height / 4) // Position higher up
        label.zPosition = 5 // Lower z-position to not block SwiftUI elements
        addChild(label)
        
        // Fade out the label after a few seconds to clear the view
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 3.0),
            SKAction.fadeOut(withDuration: 1.0),
            SKAction.removeFromParent()
        ])
        label.run(fadeOut)
        
        // Mark player as finished in database for multiplayer races
        if isRealtimeEnabled, let appEnvironment = appEnvironment {
            Task { @MainActor in
                await markPlayerFinished(appEnvironment: appEnvironment)
            }
        }
    }
    
    @MainActor
    private func markPlayerFinished(appEnvironment: AppEnvironment) async {
        // Get the race ID from the current channel or stored race ID
        guard let raceId = getCurrentRaceId() else {
            print("❌ No race ID available to mark player as finished")
            return
        }
        
        // Calculate player's finish place based on current leaderboard
        let playerPosition = leaderboard.firstIndex(where: { $0.name == "You" }) ?? 0
        let finishPlace = playerPosition + 1
        
        // Calculate average pace
        let finishTime = finishTimes[-1] ?? 0
        let distanceKm = Double(raceDistance) / 1000.0
        let averagePace = finishTime > 0 ? (finishTime / 60.0) / distanceKm : 0.0
        
        do {
            try await appEnvironment.supabaseConnection.markParticipantFinished(
                raceId: raceId,
                distance: Double(raceDistance),
                pace: averagePace,
                finishPlace: finishPlace
            )
            print("✅ Player marked as finished in race \(raceId) with place \(finishPlace)")
        } catch {
            print("❌ Error marking player as finished: \(error)")
        }
    }
    
    private func getCurrentRaceId() -> UUID? {
        return currentRaceId
    }
    
    func updateWidgetData() {
        let defaults = UserDefaults(suiteName: "group.com.kenneth.RunTogether")
        let playerPosition = leaderboard.firstIndex(where: { $0.name == "You" }) ?? 0
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
    
    // MARK: - Player Speed Control
    func setPlayerSpeed(to speed: CLLocationSpeed) {
        self.currentPlayerSpeed = speed
    }
    
    // MARK: - Utility Methods
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func calculatePace(from speedMps: CGFloat, useMiles: Bool) -> String {
        guard speedMps > 0.1 else { return "--:--" }
        
        let metersPerUnit = useMiles ? 1609.34 : 1000.0
        let paceSecondsPerUnit = metersPerUnit / Double(speedMps)
        
        let minutes = Int(paceSecondsPerUnit / 60)
        let seconds = Int(paceSecondsPerUnit.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Abstract Methods (Override in subclasses)
    func updateLeaderboard(pace: String?) {
        var currRunners: [RunnerData] = []

        // Add player
        let playerSpeed = isTreadmillMode ? currentPlayerSpeed : (locationManager?.currentSpeed ?? 0)
        let playerDisplayDistance = finishTimes[-1] != nil ? raceDistance : playerDistance // Show full distance if finished
        currRunners.append(RunnerData(
            name: "You",
            distance: playerDisplayDistance,
            pace: pace ?? "--:--",
            finishTime: finishTimes[-1],
            speed: playerSpeed
        ))

        // Add AI opponents (for non-realtime mode)
        if !isRealtimeEnabled {
            for i in 0..<otherRunners.count {
                let opponentDisplayDistance = finishTimes[i] != nil ? raceDistance : otherRunnersCurrentDistances[i] // Show full distance if finished
                currRunners.append(RunnerData(
                    name: otherRunnersNames[i],
                    distance: opponentDisplayDistance,
                    pace: calculatePace(from: otherRunnersSpeeds[i], useMiles: useMiles),
                    finishTime: finishTimes[i],
                    speed: Double(otherRunnersSpeeds[i])
                ))
            }
        } else {
            // Add realtime opponents (include stale ones if they might have finished)
            for (_, opponent) in realtimeOpponents {
                // Include all opponents, but mark stale ones with special handling
                let isFinished = opponent.distance >= Double(raceDistance) * 0.95 // Allow for small distance variations
                let shouldInclude = !opponent.isStale || isFinished
                
                if shouldInclude {
                    currRunners.append(RunnerData(
                        name: opponent.username,
                        distance: CGFloat(opponent.distance),
                        pace: opponent.paceString(),
                        finishTime: nil, // Don't set fake finish times - let RaceResultsViewModel handle this from database
                        speed: opponent.speedMps
                    ))
                    print("📊 Including opponent \(opponent.username): distance=\(opponent.distance), isFinished=\(isFinished), isStale=\(opponent.isStale)")
                } else {
                    print("📊 Excluding opponent \(opponent.username): distance=\(opponent.distance), isFinished=\(isFinished), isStale=\(opponent.isStale)")
                }
            }
        }

        // Default sorting by distance (can be overridden in subclasses)
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
    
    // MARK: - Realtime Methods

    /// Start listening to realtime updates for this race
    func startRealtimeUpdates(raceId: UUID, appEnvironment: AppEnvironment) async {
        isRealtimeEnabled = true
        currentRaceId = raceId // Store race ID for later use
        
        // First, load existing participants who are already in the race
        await loadExistingParticipants(raceId: raceId, appEnvironment: appEnvironment)
        
        // Subscribe to the race channel
        await appEnvironment.supabaseConnection.subscribeToRaceBroadcasts(raceId: raceId)
        
        // Start processing incoming messages
        Task { @MainActor in
            await processRealtimeMessages(appEnvironment: appEnvironment)
        }
    }
    
    /// Load existing participants who are already in the race
    private func loadExistingParticipants(raceId: UUID, appEnvironment: AppEnvironment) async {
        do {
            let participants = try await appEnvironment.supabaseConnection.getRaceParticipants(raceId: raceId)
            
            for participant in participants {
                // Fetch user profile for each participant
                guard let profile = try? await appEnvironment.supabaseConnection.getProfileById(userId: participant.user_id) else {
                    continue
                }
                
                // Initialize opponent data with current distance from participant record
                realtimeOpponents[participant.user_id] = RealtimeOpponentData(
                    userId: participant.user_id,
                    username: profile.username,
                    distance: participant.distance_covered,
                    paceMinutes: participant.average_pace ?? 0,
                    speedMps: 0, // Will be updated when they broadcast
                    lastUpdateTime: Date(),
                    spriteUrl: profile.selected_sprite_url,
                    country: profile.country
                )
            }
        } catch {
            // Silently handle error - race will continue with just broadcast updates
        }
    }

    /// Process incoming broadcast messages
    private func processRealtimeMessages(appEnvironment: AppEnvironment) async {
        guard let channel = appEnvironment.supabaseConnection.currentChannel else {
            return
        }
        
        let stream = channel.broadcastStream(event: "update")
        
        for await message in stream {
//            print("📡 Received broadcast message: \(message)")
            
            // Extract payload from the message
            guard let payload = message["payload"]?.objectValue else {
                continue
            }
            
            guard let userIdString = payload["user_id"]?.stringValue,
                  let userId = UUID(uuidString: userIdString),
                  userId != appEnvironment.supabaseConnection.currentUserId else {
                continue // Skip our own messages
            }
            
            let distance = payload["distance"]?.doubleValue ?? 0
            let pace = payload["pace"]?.doubleValue ?? 0
            let speedMps = payload["speed"]?.doubleValue ?? (pace > 0 ? 1000 / (pace * 60) : 0) // Use broadcast speed or fallback to calculated
            
//            print("👤 Processing update for user \(userId): distance=\(distance), pace=\(pace), speed=\(speedMps)")
            
            // Update or create opponent data
            if realtimeOpponents[userId] != nil {
//                print("🔄 Updating existing opponent \(userId)")
                realtimeOpponents[userId]?.distance = distance
                realtimeOpponents[userId]?.paceMinutes = pace
                realtimeOpponents[userId]?.speedMps = speedMps
                realtimeOpponents[userId]?.lastUpdateTime = Date()
            } else {
                // Fetch username and sprite for new opponent
                Task { @MainActor in
                    guard let profile = try? await appEnvironment.supabaseConnection.getProfileById(userId: userId) else {
                        return
                    }
                    
                    realtimeOpponents[userId] = RealtimeOpponentData(
                        userId: userId,
                        username: profile.username,
                        distance: distance,
                        paceMinutes: pace,
                        speedMps: speedMps,
                        lastUpdateTime: Date(),
                        spriteUrl: profile.selected_sprite_url,
                        country: profile.country
                    )
                }
            }
        }
    }

    /// Sync realtime opponent data to visible runners on screen
    @MainActor
    private func syncRealtimeOpponentsToScene() {
        // Remove stale opponents (but keep finished ones)
        realtimeOpponents = realtimeOpponents.filter { 
            !$0.value.isStale || $0.value.distance >= Double(raceDistance) 
        }
        
        // Sort by userId to maintain consistent ordering
        let activeOpponents = realtimeOpponents.sorted(by: { $0.key.uuidString < $1.key.uuidString }).map { $0.value }
        
        // Update existing runners or create new ones
        while otherRunners.count < activeOpponents.count && otherRunners.count < 10 {
            let index = otherRunners.count
            let opponent = activeOpponents[index]
            
            print("🏃 Creating runner for \(opponent.username) with sprite URL: \(opponent.spriteUrl ?? "nil")")
            
            let runnerNode = createRunner(
                name: opponent.username,
                nationality: opponent.country ?? "",
                spriteUrl: opponent.spriteUrl
            )
            // Position runners in lanes to avoid overlapping with player (who is at x: 0)
            let laneSpacing: CGFloat = 120
            // Alternate runners left and right of center, avoiding x: 0
            let laneOffset = index % 2 == 0 ? 
                CGFloat((index / 2 + 1)) * laneSpacing :  // Right side: +120, +240, +360...
                -CGFloat(((index + 1) / 2)) * laneSpacing  // Left side: -120, -240, -360...
            let baseY = -frame.height / 2.5 + (frame.height * 0.2)
            runnerNode.position = CGPoint(x: laneOffset, y: baseY)
            
            addChild(runnerNode)
            otherRunners.append(runnerNode)
            otherRunnersNames.append(opponent.username)
            otherRunnersCurrentDistances.append(CGFloat(opponent.distance))
            otherRunnersSpeeds.append(CGFloat(opponent.paceMinutes > 0 ? 1000 / (opponent.paceMinutes * 60) : 0))
            
            if let sprite = runnerNode.childNode(withName: "runnerSprite") {
                // Only start animation if the opponent is actually moving
                if opponent.speedMps > 0.1 {
                    let customTexture = customSpriteTextures[opponent.username]
                    sprite.run(runAnimation(speedMultiplier: CGFloat(opponent.speedMps) / 3.0, customTexture: customTexture))
                }
                // If speed is 0 or very low, leave sprite in idle state (no animation)
            }
            
            // Initialize previousOpponentSpeeds for this new runner
            if previousOpponentSpeeds.count < otherRunners.count {
                previousOpponentSpeeds.append(CGFloat(opponent.speedMps))
            }
        }
        
        // Update distances and speeds for existing opponents
        for (index, opponent) in activeOpponents.prefix(otherRunners.count).enumerated() {
            otherRunnersCurrentDistances[index] = CGFloat(opponent.distance)
            
            // Convert pace (min/unit) to speed (m/s)
            let speedMps = opponent.paceMinutes > 0 ? 1000 / (opponent.paceMinutes * 60) : 0
            otherRunnersSpeeds[index] = CGFloat(speedMps)
            otherRunnersNames[index] = opponent.username
            
            // Update the name label on the sprite if it changed
            let runnerNode = otherRunners[index]
            if let labelContainer = runnerNode.children.first(where: { $0 is SKNode && $0.children.count > 1 }),
               let nameLabel = labelContainer.children.first(where: { $0 is SKLabelNode }) as? SKLabelNode {
                if nameLabel.text != opponent.username {
                    nameLabel.text = opponent.username
                }
            }
        }
    }

    /// Stop realtime updates when leaving race
    func stopRealtimeUpdates() {
        isRealtimeEnabled = false
        currentRaceId = nil
        realtimeOpponents.removeAll()
        
        // Clear visual runners
        for runnerNode in otherRunners {
            runnerNode.removeFromParent()
        }
        otherRunners.removeAll()
        otherRunnersNames.removeAll()
        otherRunnersCurrentDistances.removeAll()
        otherRunnersSpeeds.removeAll()
        previousOpponentSpeeds.removeAll()
        previousOpponentPositions.removeAll()
        
        print("🧹 Cleared all visual runners and realtime state")
    }

    // MARK: - Update existing update() method

    // Replace the updateOpponents section in your update() method with this:
    private func updateOpponentsRealtime(deltaTime: TimeInterval, currentTime: TimeInterval) {
        // First sync any new realtime data synchronously
        if isRealtimeEnabled {
            syncRealtimeOpponentsToSceneSync()
        }
        
        // Ensure previousOpponentSpeeds array is sized correctly
        while previousOpponentSpeeds.count < otherRunners.count {
            previousOpponentSpeeds.append(0)
        }
        
        // Initialize previous positions array if needed
        if previousOpponentPositions.count != otherRunners.count {
            previousOpponentPositions = otherRunnersCurrentDistances
        }
        
        // Then update visual positions (same as before)
        for i in 0..<otherRunners.count {
            let runnerNode = otherRunners[i]
            let runnerSprite = runnerNode.childNode(withName: "runnerSprite")!
            
            let runnerDistance = otherRunnersCurrentDistances[i]
            let delta = runnerDistance - playerDistance
            
            // Detect passing: Check if player passed this opponent or got passed
            if i < previousOpponentPositions.count {
                let previousDelta = previousOpponentPositions[i] - playerDistance
                // If the sign changed (was ahead, now behind or vice versa) and we're close
                if abs(delta) < 10 && abs(previousDelta) < 10 && 
                   (delta > 0 && previousDelta <= 0 || delta < 0 && previousDelta >= 0) &&
                   currentTime - lastPassingSoundTime > 1.0 { // Throttle to once per second
                    // Play passing sound
                    if let appEnvironment = appEnvironment {
                        Task { @MainActor in
                            appEnvironment.soundManager.playRunnerPassing()
                        }
                    }
                    lastPassingSoundTime = currentTime
                }
            }
            
            runnerNode.isHidden = runnerDistance >= raceDistance || delta <= -50 || delta > 500
            
            if !runnerNode.isHidden {
                let baseY = -frame.height / 2.5 + (frame.height * 0.2)
                let maxVisibleDelta: CGFloat = 500
                let progress = min(delta / maxVisibleDelta, 1.0)
                
                // Stagger runners slightly left/right into "lanes"
                let laneSpacing: CGFloat = 120
                // Use the same alternating pattern as when creating runners
                let laneOffset = i % 2 == 0 ? 
                    CGFloat((i / 2 + 1)) * laneSpacing :  // Right side: +120, +240, +360...
                    -CGFloat(((i + 1) / 2)) * laneSpacing  // Left side: -120, -240, -360...
                
                // Converge towards center as they get further ahead
                // Close runners: spread out in lanes, Far runners: converge to center
                let convergeFactor = progress // 0 = at player position, 1 = far ahead
                let offsetX = laneOffset * (1.0 - convergeFactor) // Reduce lane offset as they get further
                
                runnerNode.position = CGPoint(x: offsetX, y: baseY)
                
                let shrinkStrength: CGFloat = 1.0
                let scaleFactor = max(0.2, 1.0 - (delta / maxVisibleDelta) * shrinkStrength)
                runnerNode.setScale(scaleFactor)
                
                let newSpeed = otherRunnersSpeeds[i]
                if i < previousOpponentSpeeds.count {
                    if abs(previousOpponentSpeeds[i] - newSpeed) > 0.1 {
                        runnerSprite.removeAllActions()
                        
                        // Only animate if the runner is actually moving
                        if newSpeed > 0.1 {
                            let opponentName = otherRunnersNames[i]
                            let customTexture = customSpriteTextures[opponentName]
                            runnerSprite.run(runAnimation(speedMultiplier: newSpeed / 3.0, customTexture: customTexture))
                        }
                        // If speed is 0 or very low, leave sprite in idle state (no animation)
                        
                        previousOpponentSpeeds[i] = newSpeed
                    }
                }
            }
            
            // Update previous position for next frame
            if i < previousOpponentPositions.count {
                previousOpponentPositions[i] = runnerDistance
            }
            
            if runnerDistance >= raceDistance && finishTimes[i] == nil {
                finishTimes[i] = currentTime - (startTime ?? currentTime)
            }
        }
    }
    
    /// Synchronous version of syncRealtimeOpponentsToScene for use in update loop
    private func syncRealtimeOpponentsToSceneSync() {
        // Remove stale opponents (but keep finished ones)
        let beforeCount = realtimeOpponents.count
        realtimeOpponents = realtimeOpponents.filter { 
            !$0.value.isStale || $0.value.distance >= Double(raceDistance) 
        }
        
        // Sort by userId to maintain consistent ordering
        let activeOpponents = realtimeOpponents.sorted(by: { $0.key.uuidString < $1.key.uuidString }).map { $0.value }
        
//        if activeOpponents.count > 0 {
//            print("🔄 Syncing \(activeOpponents.count) active opponents to scene (current runners: \(otherRunners.count))")
//        }
        
        // Update existing runners or create new ones
        while otherRunners.count < activeOpponents.count && otherRunners.count < 10 {
            let index = otherRunners.count
            let opponent = activeOpponents[index]
            
            let runnerNode = createRunner(
                name: opponent.username,
                nationality: opponent.country ?? "",
                spriteUrl: opponent.spriteUrl
            )
            // Position runners in lanes to avoid overlapping with player (who is at x: 0)
            let laneSpacing: CGFloat = 120
            // Alternate runners left and right of center, avoiding x: 0
            let laneOffset = index % 2 == 0 ? 
                CGFloat((index / 2 + 1)) * laneSpacing :  // Right side: +120, +240, +360...
                -CGFloat(((index + 1) / 2)) * laneSpacing  // Left side: -120, -240, -360...
            let baseY = -frame.height / 2.5 + (frame.height * 0.2)
            runnerNode.position = CGPoint(x: laneOffset, y: baseY)
            
            addChild(runnerNode)
            otherRunners.append(runnerNode)
            otherRunnersNames.append(opponent.username)
            otherRunnersCurrentDistances.append(CGFloat(opponent.distance))
            otherRunnersSpeeds.append(CGFloat(opponent.speedMps))
            
            if let sprite = runnerNode.childNode(withName: "runnerSprite") {
                // Only start animation if the opponent is actually moving
                if opponent.speedMps > 0.1 {
                    let customTexture = customSpriteTextures[opponent.username]
                    sprite.run(runAnimation(speedMultiplier: CGFloat(opponent.speedMps) / 3.0, customTexture: customTexture))
                }
                // If speed is 0 or very low, leave sprite in idle state (no animation)
            }
            
            // Initialize previousOpponentSpeeds for this new runner
            if previousOpponentSpeeds.count < otherRunners.count {
                previousOpponentSpeeds.append(CGFloat(opponent.speedMps))
            }
        }
        
        // Update distances and speeds for existing opponents
        for (index, opponent) in activeOpponents.prefix(otherRunners.count).enumerated() {
            otherRunnersCurrentDistances[index] = CGFloat(opponent.distance)
            otherRunnersSpeeds[index] = CGFloat(opponent.speedMps)
            otherRunnersNames[index] = opponent.username
            
            // Update the name label on the sprite if it changed
            let runnerNode = otherRunners[index]
            if let labelContainer = runnerNode.children.first(where: { $0 is SKNode && $0.children.count > 1 }),
               let nameLabel = labelContainer.children.first(where: { $0 is SKLabelNode }) as? SKLabelNode {
                if nameLabel.text != opponent.username {
                    nameLabel.text = opponent.username
                }
            }
        }
    }
}
