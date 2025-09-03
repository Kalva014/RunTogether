//
//  RunningView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/27/25.
//
import SwiftUI
import SpriteKit

// Basically renders the runners and logic for racing
class RaceScene: SKScene {
    var playerRunner: SKNode!
    var otherRunners: [SKNode] = []
    var raceDistance: CGFloat = 5000 // e.g., 5K in meters
    var playerDistance: CGFloat = 0
    var scrollSpeed: CGFloat = 5.0
    var finishLine: SKSpriteNode!
    
    // Background track nodes for looping
    var track1: SKSpriteNode!
    var track2: SKSpriteNode!
    var scrollingGroundNodes: [SKSpriteNode] = []
    
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
    
    // Handle race completion
    func raceFinished() {
        isPaused = true
        
        let label = SKLabelNode(text: "Race Complete!")
        label.fontName = "Avenir-Heavy"
        label.fontSize = 40
        label.fontColor = .yellow
        label.position = CGPoint(x: 0, y: 0)
        label.zPosition = 100
        addChild(label)
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
        
        // Add finish line banner
        finishLine = SKSpriteNode(imageNamed: "FinishLineBanner")
        finishLine.size = CGSize(width: frame.width * 0.8, height: 60)
        finishLine.position = CGPoint(x: 0, y: raceDistance / 10) // scale meters→pixels
        finishLine.zPosition = 5
        addChild(finishLine)
        
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
    }
    
    // Calls this func every frame
    override func update(_ currentTime: TimeInterval) {
        playerDistance += scrollSpeed
        
        // Initialize infinite looping ground
        guard let groundHeight = scrollingGroundNodes.first?.size.height else { return }
                    
        for ground in scrollingGroundNodes {
            ground.position.y -= scrollSpeed
            
            // When the tile moves completely off-screen (bottom), snap it directly above the current highest tile
            if ground.position.y <= -frame.height/2 - groundHeight {
                if let topMost = scrollingGroundNodes.max(by: { $0.position.y < $1.position.y }) {
                    ground.position.y = topMost.position.y + groundHeight - 10 // Added 10 overlap
                }
            }
        }
        
        // Finish line could also "zoom" like a track sprite
        if playerDistance >= raceDistance {
            raceFinished()
        }
    }
}

// Basically renders the runners and the logic for the casual run club
class RunClubScene: SKScene {
    
}

struct RunningView: View {
    let mode: String;
    
    // Initialize the scene
    var scene: SKScene {
        let scene: SKScene;
        
        // Choose what mode
        if (mode == "Race") {
            scene = RaceScene()
        }
        else {
            scene = RunClubScene()
        }
        
        scene.size = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        scene.scaleMode = .fill
        return scene
    }
    
    var body: some View {
        ZStack {
            SpriteView(scene: scene)
            
            VStack {
                Text("Runners Leaderboard").bold()
                
                HStack{
                    Text("Runner's Name")
                    Text("Distance")
                    Text("Pace")
                }
            }
            
            HStack {
                Button("Settings") {}
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure ZStack fills space
        .ignoresSafeArea() // Apply ignoresSafeArea to the entire ZStack
    }
}

#Preview {
    RunningView(mode: "Race")
        .environmentObject(AppEnvironment())
}
