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
    var otherRunnersCurrentDistances: [CGFloat] = [50, 120] // starting distances
    var otherRunnersSpeeds: [CGFloat] = [2.8, 3.5]
    var otherRunnersNames: [String] = []
    var previousOpponentSpeeds: [CGFloat] = []
    var previousPlayerSpeedMultiplier: CGFloat = 0.0
    
    // MARK: - Visual Elements
    var backgroundTexture: SKTexture!
    
    // MARK: - Combine
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Realtime Multiplayer State
    var realtimeOpponents: [UUID: RealtimeOpponentData] = [:] // Track all opponents by userId
    var isRealtimeEnabled: Bool = false

    struct RealtimeOpponentData {
        let userId: UUID
        let username: String
        var distance: Double
        var paceMinutes: Double // pace in minutes per unit (km or mi)
        var speedMps: Double // speed in meters per second
        var lastUpdateTime: Date
        
        // Check if data is stale (no update in 10 seconds)
        var isStale: Bool {
            Date().timeIntervalSince(lastUpdateTime) > 10
        }
        
        // Convert pace to formatted string
        func paceString() -> String {
            let minutes = Int(paceMinutes)
            let seconds = Int((paceMinutes * 60).truncatingRemainder(dividingBy: 60))
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
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
        playerRunner = createRunner(name: "You", nationality: "UnitedStatesFlag", isPlayer: true)
        let runnerY = -frame.height / 2.5 + (frame.height * 0.2)
        playerRunner.position = CGPoint(x: 0, y: runnerY)
        addChild(playerRunner)
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
    
    func runAnimation(speedMultiplier: CGFloat = 1.0) -> SKAction {
        // 1. Load textures from your asset catalog
//        let standFrame = SKTexture(imageNamed: "MaleRunnerStanding")
//        let runFrame = SKTexture(imageNamed: "MaleRunner")
        let sprintingFrame = SKTexture(imageNamed: "MaleRunerSprinting")

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

    private func updateOpponents(deltaTime: TimeInterval, currentTime: TimeInterval) {
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

                // 6. Update runner's screen position
                runnerNode.position = CGPoint(x: offsetX + laneOffset, y: baseY)

                // 7. Scale runner by distance gap (farther = smaller, shrinks faster now)
                let shrinkStrength: CGFloat = 1.0    // stronger scaling curve
                let scaleFactor = max(0.2, 1.0 - (delta / maxVisibleDelta) * shrinkStrength)
                runnerNode.setScale(scaleFactor)

                // 8. Update animation speed if this runner's speed changed
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
        playerRunner.zPosition = 10
        for i in 0..<otherRunners.count {
            otherRunners[i].zPosition = otherRunnersCurrentDistances[i] < raceDistance ? 9 : 8
        }
    }
    
    // MARK: - Race Management
    func raceFinished() {
        guard !isRaceOver else { return }
        isRaceOver = true

        // Stop the player's motion immediately
        playerDistance = raceDistance
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
        currRunners.append(RunnerData(
            name: "Ken",
            distance: playerDistance,
            pace: pace ?? "--:--",
            finishTime: finishTimes[-1],
            speed: playerSpeed
        ))

        // Add AI opponents (for non-realtime mode)
        if !isRealtimeEnabled {
            for i in 0..<otherRunners.count {
                currRunners.append(RunnerData(
                    name: otherRunnersNames[i],
                    distance: otherRunnersCurrentDistances[i],
                    pace: calculatePace(from: otherRunnersSpeeds[i], useMiles: useMiles),
                    finishTime: finishTimes[i],
                    speed: Double(otherRunnersSpeeds[i])
                ))
            }
        } else {
            // Add realtime opponents
            for (userId, opponent) in realtimeOpponents where !opponent.isStale {
                currRunners.append(RunnerData(
                    name: opponent.username,
                    distance: CGFloat(opponent.distance),
                    pace: opponent.paceString(),
                    finishTime: nil, // Realtime opponents don't have finish times yet
                    speed: opponent.speedMps
                ))
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
        
        // Subscribe to the race channel
        await appEnvironment.supabaseConnection.subscribeToRaceBroadcasts(raceId: raceId)
        
        // Start processing incoming messages
        Task { @MainActor in
            await processRealtimeMessages(appEnvironment: appEnvironment)
        }
    }

    /// Process incoming broadcast messages
    private func processRealtimeMessages(appEnvironment: AppEnvironment) async {
        guard let channel = appEnvironment.supabaseConnection.currentChannel else { return }
        
        let stream = await channel.broadcastStream(event: "update")
        
        for await message in stream {
            guard let userIdString = message["user_id"]?.stringValue,
                  let userId = UUID(uuidString: userIdString),
                  userId != appEnvironment.supabaseConnection.currentUserId else {
                continue // Skip our own messages
            }
            
            let distance = message["distance"]?.doubleValue ?? 0
            let pace = message["pace"]?.doubleValue ?? 0
            
            // Update or create opponent data
            if realtimeOpponents[userId] != nil {
                realtimeOpponents[userId]?.distance = distance
                realtimeOpponents[userId]?.paceMinutes = pace
                realtimeOpponents[userId]?.lastUpdateTime = Date()
            } else {
                // Fetch username for new opponent
                Task {
                    if let profile = try? await appEnvironment.supabaseConnection.getProfileById(userId: userId) {
                        realtimeOpponents[userId] = RealtimeOpponentData(
                            userId: userId,
                            username: profile.username ?? "Unknown",
                            distance: distance,
                            paceMinutes: pace,
                            speedMps: pace > 0 ? 1000 / (pace * 60) : 0, // or calculate speed here
                            lastUpdateTime: Date()
                        )
                        
                        // Add visual runner if needed
                        await syncRealtimeOpponentsToScene()
                    }
                }
            }
        }
    }

    /// Sync realtime opponent data to visible runners on screen
    @MainActor
    private func syncRealtimeOpponentsToScene() {
        // Remove stale opponents
        realtimeOpponents = realtimeOpponents.filter { !$0.value.isStale }
        
        let activeOpponents = Array(realtimeOpponents.values)
        
        // Update existing runners or create new ones
        while otherRunners.count < activeOpponents.count && otherRunners.count < 10 {
            let index = otherRunners.count
            let opponent = activeOpponents[index]
            
            let runnerNode = createRunner(
                name: opponent.username,
                nationality: "UnitedStatesFlag" // Could be dynamic based on profile
            )
            runnerNode.position = CGPoint(x: 0, y: 100 + CGFloat(index) * 50)
            addChild(runnerNode)
            otherRunners.append(runnerNode)
            otherRunnersNames.append(opponent.username)
            otherRunnersCurrentDistances.append(CGFloat(opponent.distance))
            otherRunnersSpeeds.append(CGFloat(opponent.paceMinutes > 0 ? 1000 / (opponent.paceMinutes * 60) : 0))
            
            if let sprite = runnerNode.childNode(withName: "runnerSprite") {
                sprite.run(runAnimation())
            }
        }
        
        // Update distances and speeds for existing opponents
        for (index, opponent) in activeOpponents.prefix(otherRunners.count).enumerated() {
            otherRunnersCurrentDistances[index] = CGFloat(opponent.distance)
            
            // Convert pace (min/unit) to speed (m/s)
            let speedMps = opponent.paceMinutes > 0 ? 1000 / (opponent.paceMinutes * 60) : 0
            otherRunnersSpeeds[index] = CGFloat(speedMps)
            otherRunnersNames[index] = opponent.username
        }
    }

    /// Stop realtime updates when leaving race
    func stopRealtimeUpdates() {
        isRealtimeEnabled = false
        realtimeOpponents.removeAll()
    }

    // MARK: - Update existing update() method

    // Replace the updateOpponents section in your update() method with this:
    private func updateOpponentsRealtime(deltaTime: TimeInterval, currentTime: TimeInterval) {
        // First sync any new realtime data
        if isRealtimeEnabled {
            Task { @MainActor in
                await syncRealtimeOpponentsToScene()
            }
        }
        
        // Then update visual positions (same as before)
        for i in 0..<otherRunners.count {
            let runnerNode = otherRunners[i]
            let runnerSprite = runnerNode.childNode(withName: "runnerSprite")!
            
            let runnerDistance = otherRunnersCurrentDistances[i]
            let delta = runnerDistance - playerDistance
            
            runnerNode.isHidden = runnerDistance >= raceDistance || delta <= -50 || delta > 500
            
            if !runnerNode.isHidden {
                let baseY = -frame.height / 2.5 + (frame.height * 0.2)
                let maxVisibleDelta: CGFloat = 500
                let trackWidth: CGFloat = frame.width * 0.8
                let progress = min(delta / maxVisibleDelta, 1.0)
                let offsetX = progress * trackWidth - (trackWidth / 2)
                let laneSpacing: CGFloat = 80
                let laneOffset = CGFloat(i - otherRunners.count / 2) * laneSpacing
                
                runnerNode.position = CGPoint(x: offsetX + laneOffset, y: baseY)
                
                let shrinkStrength: CGFloat = 1.0
                let scaleFactor = max(0.2, 1.0 - (delta / maxVisibleDelta) * shrinkStrength)
                runnerNode.setScale(scaleFactor)
                
                let newSpeed = otherRunnersSpeeds[i]
                if previousOpponentSpeeds[i] != newSpeed {
                    runnerSprite.removeAllActions()
                    runnerSprite.run(runAnimation(speedMultiplier: newSpeed / 3.0))
                    previousOpponentSpeeds[i] = newSpeed
                }
            }
            
            if runnerDistance >= raceDistance && finishTimes[i] == nil {
                finishTimes[i] = currentTime - (startTime ?? currentTime)
            }
        }
    }
}
