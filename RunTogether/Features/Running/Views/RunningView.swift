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
    
    // This method is called when your game scene is ready to run
    override func didMove(to view: SKView) {
        // Set the scene origin to the center
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        // Create the user's runner
        let runner1 = createRunner(name: "Ken", nationality: "UnitedStatesFlag")
        runner1.position = .zero
        addChild(runner1)
        let runnerSprite = runner1.childNode(withName: "runnerSprite")
        
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
        runnerSprite?.run(runAnimation)
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
