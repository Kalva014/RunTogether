//
//  RunTogetherApp.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 7/31/25.
//

import SwiftUI

@main
struct RunTogetherApp: App {
    @StateObject var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appEnvironment)
        }
    }
}
