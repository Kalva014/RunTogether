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
    // This method is called when your game scene is ready to run
    override func didMove(to view: SKView) {
        // Create and position the runner on the screen
        let runner = SKSpriteNode(imageNamed: "MaleRunner")
        runner.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(runner)
        
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
        runner.run(runAnimation)
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
