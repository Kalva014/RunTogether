//
//  RunningView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/27/25.
//
import SwiftUI
import SpriteKit

// Basically renders the runners and logic for racing
class RaceScene: SKScene, ObservableObject {
    @Published var leaderboard: [RunnerData] = []
    
    var playerRunner: SKNode!
    var otherRunners: [SKNode] = []
    var raceDistance: CGFloat = 2000 // e.g., 5K in meters
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
    func runAnimation() -> SKAction {
        // Flip the image to make it look like it is moving
        let flipRight = SKAction.scaleX(to: 1, duration: 0)
        let flipLeft = SKAction.scaleX(to: -1, duration: 0)
        
        // Define a pause between flips
        let delay = SKAction.wait(forDuration: 0.2)
        
        let runSequence = SKAction.sequence([
            flipLeft,
            delay,
            flipRight,
            delay
        ])
        
        // Make it run in a loop
        let runAnimation: SKAction = .repeatForever(runSequence);
        return runAnimation
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
        newFinishLine.zPosition = 5
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
        topCover.position = CGPoint(x: 0, y: -frame.height / 3)
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
        
        startTime = CACurrentMediaTime()
    }
    
    // Updates every frame
    override func update(_ currentTime: TimeInterval) {
        let currentTime = CACurrentMediaTime()
        
        // Player
        if playerDistance >= raceDistance && finishTimes[-1] == nil {
            finishTimes[-1] = currentTime - (startTime ?? currentTime)
            raceFinished()
        }

        // Opponents
        for i in 0..<otherRunners.count {
            if otherRunnersCurrentDistances[i] >= raceDistance && finishTimes[i] == nil {
                finishTimes[i] = currentTime - (startTime ?? currentTime)
            }
        }

        // Move the player only if race is not finished
        if !isRaceOver {
            playerDistance = min(playerDistance + scrollSpeed, raceDistance)
        }

        // Move ground only while the player is moving
        if !isRaceOver {
            guard let groundHeight = scrollingGroundNodes.first?.size.height else { return }
            for ground in scrollingGroundNodes {
                ground.position.y -= scrollSpeed
                if ground.position.y <= -frame.height/2 - groundHeight {
                    if let topMost = scrollingGroundNodes.max(by: { $0.position.y < $1.position.y }) {
                        ground.position.y = topMost.position.y + groundHeight - 10
                    }
                }
            }
        }

        var currRunners: [RunnerData] = []
        currRunners.append(RunnerData(name: "Ken", distance: playerDistance, pace: calculatePace(for: playerDistance)))

        for i in 0..<otherRunners.count {
            // Move runner forward, capped at raceDistance
            otherRunnersCurrentDistances[i] = min(otherRunnersCurrentDistances[i] + otherRunnersSpeeds[i], raceDistance)

            let runnerNode = otherRunners[i]
            let runnerDistance = otherRunnersCurrentDistances[i]
            let delta = runnerDistance - playerDistance

            // Hide runner if finished or too far behind/ahead
            if runnerDistance >= raceDistance || delta <= 0 || delta > 1000 {
                runnerNode.isHidden = true
            } else {
                runnerNode.isHidden = false
                let baseY = -frame.height / 2.5 + (frame.height * 0.2)
                let offsetX = CGFloat(i - otherRunners.count / 2) * 50
                runnerNode.position = CGPoint(x: offsetX, y: baseY)
                let scaleFactor = max(0.3, 1.0 - (delta / 1000.0) * 0.7)
                runnerNode.setScale(scaleFactor)
            }

            let displayDistance = min(runnerDistance, raceDistance)
            currRunners.append(RunnerData(
                name: "Opponent \(i+1)",
                distance: displayDistance,
                pace: calculatePace(for: displayDistance)
            ))
        }

        leaderboard = currRunners.sorted(by: { $0.distance > $1.distance })

        // Call finish only once when player reaches distance
        if playerDistance >= raceDistance && !isRaceOver {
            raceFinished()
        }
    }
}

// Basically renders the runners and the logic for the casual run club
class RunClubScene: SKScene {
    
}

struct RunningView: View {
    let mode: String

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
            // Set the scene size and scale only once
            raceScene.size = CGSize(
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height
            )
            raceScene.scaleMode = .fill
        }
    }
}

#Preview {
    RunningView(mode: "Race")
        .environmentObject(AppEnvironment())
}
