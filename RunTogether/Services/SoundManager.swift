//
//  SoundManager.swift
//  RunTogether
//
//  Created for professional sound effects integration
//

import Foundation
import AVFoundation
import AudioToolbox

/// Manages all sound effects in the app using both system sounds and custom audio files
@MainActor
class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    // MARK: - Properties
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var isSoundEnabled: Bool = true
    
    // MARK: - Initialization
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - System Sounds (Built-in iOS sounds)
    /// Plays a system sound effect
    /// - Parameter soundID: SystemSoundID from AudioToolbox (e.g., 1104 for tap, 1057 for success)
    func playSystemSound(_ soundID: SystemSoundID) {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(soundID)
    }
    
    // MARK: - Custom Sound Effects
    /// Plays a custom sound file from the app bundle
    /// - Parameters:
    ///   - fileName: Name of the sound file (without extension)
    ///   - extension: File extension (default: "wav")
    func playCustomSound(fileName: String, extension: String = "wav") {
        guard isSoundEnabled else { return }
        
        // Check if player already exists
        if let player = audioPlayers[fileName] {
            player.stop()
            player.currentTime = 0
            player.play()
            return
        }
        
        // Load and play new sound
        guard let url = Bundle.main.url(forResource: fileName, withExtension: `extension`) else {
            print("⚠️ Sound file not found: \(fileName).\(`extension`)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.7
            player.prepareToPlay()
            player.play()
            audioPlayers[fileName] = player
        } catch {
            print("❌ Error playing sound \(fileName): \(error)")
        }
    }
    
    // MARK: - Predefined Sound Effects
    
    /// Button tap sound (light, subtle)
    func playTap() {
        playSystemSound(1104) // System tap sound
    }
    
    /// Success/confirmation sound
    func playSuccess() {
        playSystemSound(1057) // System success sound
    }
    
    /// Error/warning sound
    func playError() {
        playSystemSound(1053) // System error sound
    }
    
    /// Navigation/transition sound
    func playNavigation() {
        playSystemSound(1103) // System navigation sound
    }
    
    /// Tab switch sound
    func playTabSwitch() {
        playSystemSound(1104) // Light tap for tab switching
    }
    
    /// Race start sound
    func playRaceStart() {
        playSystemSound(1105) // System alert sound for race start
    }
    
    /// Race finish/celebration sound
    func playRaceFinish() {
        playSystemSound(1057) // Success sound for finishing
    }
    
    /// Runner passing sound (uses custom sound if available)
    func playRunnerPassing() {
        // Try custom sound first, fallback to system sound
        if Bundle.main.url(forResource: "runner_passing", withExtension: "wav") != nil {
            playCustomSound(fileName: "runner_passing", extension: "wav")
        } else {
            playSystemSound(1104) // Fallback to tap sound
        }
    }
    
    // MARK: - Sound Control
    /// Enable or disable all sounds
    func setSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
    }
    
    /// Check if sounds are enabled
    var soundsEnabled: Bool {
        return isSoundEnabled
    }
}

