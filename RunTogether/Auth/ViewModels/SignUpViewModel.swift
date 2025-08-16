//
//  SignUpViewModel.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 8/11/25.
//

import Foundation

class SignUpViewModel: ObservableObject {
    @Published var res = "";
    let dbConnect = CloudKitConnection();
    
    func signUp() async {
        do {
//            try await dbConnect.createRecord();
//            try await dbConnect.readRecord()
//            try await dbConnect.updateRecord()
            try await dbConnect.deleteRecord()
        } catch {
                print("Sign up failed: \(error.localizedDescription)")
        }
    }
}
