//
//  ContentView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 7/31/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            NavigationLink {
                SignUpView()
            } label: {
                Text("Sign Up!")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
