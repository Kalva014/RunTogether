//
//  RunTogetherApp.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 7/31/25.
//

import SwiftUI

@main
struct RunTogetherApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
