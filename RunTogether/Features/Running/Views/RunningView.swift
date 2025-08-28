//
//  RunningView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/27/25.
//
import SwiftUI
import SpriteKit

// Basically the user's person aka the sprite itself
class CharacterScene: SKScene {
    var viewModel: CharacterViewModel
    var characterNode: SKSpriteNode
    
    init(size: CGSize, viewModel: CharacterViewModel) {
        self.viewModel = viewModel
        self.characterNode = SKSpriteNode(imageNamed: "MaleRunner") // Load the MaleRunner image
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Basically you set up your sprite when the scene is presented on the view
    override func didMove(to view: SKView) {
        backgroundColor = .clear // Make the background transparent
        characterNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        characterNode.setScale(0.5) // Adjust scale as needed
        addChild(characterNode)
    }
}

// The actual view
struct RunningView: View {
    @StateObject var characterViewModel = CharacterViewModel()
    var scene: SKScene {
        let scene = CharacterScene(size: CGSize(width: 300, height: 300), viewModel: characterViewModel)
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
    }
}

#Preview {
    RunningView()
        .environmentObject(AppEnvironment())
}
