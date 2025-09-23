//
//  GroupTabView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/22/25.
//

import SwiftUI

struct GroupTabView: View {
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            Text("Group Tab View")
                .font(.headline)
                .padding()
            
            List {
                
            }.searchable(text: $searchText, prompt: "Find Run Club")
        }
    }
}

#Preview {
    GroupTabView()
        .environmentObject(AppEnvironment(appUser: AppUser(id: UUID().uuidString, email: "test@example.com", username: "testuser")))
}
