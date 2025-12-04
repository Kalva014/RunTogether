//
//  SafetyTipBanner.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 12/4/25.
//

import SwiftUI

struct SafetyTipBanner: View {
    let tip: SafetyTip
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: tip.icon)
                    .font(.title3)
                    .foregroundColor(.orange)
                
                Text(tip.message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
            .background(
                Color.black.opacity(0.9)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 8)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.top, 120) // Position below top stats
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: tip.id)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        SafetyTipBanner(
            tip: SafetyTip(
                icon: "eye.fill",
                message: "Stay aware of your surroundings at all times"
            ),
            onDismiss: {}
        )
    }
}
