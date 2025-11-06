//
//  Untitled.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/28/25.
//
import SwiftUI

enum CharacterAnimations {
    case idle
    case walking
    case running
}

struct CharacterModel {
    var position: CGPoint
    var animation: CharacterAnimations
}

struct RunnerData: Identifiable {
    let id = UUID()
    let name: String
    let distance: CGFloat
    let pace: String
    let finishTime: TimeInterval?
    var speed: Double?
    var profilePictureUrl: String? = nil
}
