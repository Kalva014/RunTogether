//
//  RunTogetherApp.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 7/31/25.
//

import SwiftUI

@main
struct RunTogetherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var supabaseConnection = SupabaseConnection()
    @StateObject var appEnvironment: AppEnvironment

    init() {
        let supabaseConnection = SupabaseConnection()
        self._supabaseConnection = StateObject(wrappedValue: supabaseConnection)
        self._appEnvironment = StateObject(wrappedValue: AppEnvironment(supabaseConnection: supabaseConnection))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appEnvironment)
        }
    }
}
