//
//  SignUpView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/11/25.
//

import SwiftUI

struct SignUpView: View {
    @StateObject var viewModel = SignUpViewModel();

    var body: some View {
        VStack {
            Label("Create An Account!", systemImage: "42.circle")
            
            Button("Sign Up") {
                Task {
                    await viewModel.signUp()
                }
            }
        }
    }
}

#Preview {
    SignUpView()
}
