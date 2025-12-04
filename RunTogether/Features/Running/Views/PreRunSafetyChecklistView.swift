//
//  PreRunSafetyChecklistView.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 12/4/25.
//

import SwiftUI

struct PreRunSafetyChecklistView: View {
    @Binding var isPresented: Bool
    @State private var checkedItems: Set<Int> = []
    let onContinue: () -> Void
    
    private let checklistItems = [
        ChecklistItem(
            icon: "flame.fill",
            title: "Warm Up",
            description: "I have warmed up or will warm up before running"
        ),
        ChecklistItem(
            icon: "eye.fill",
            title: "Surroundings",
            description: "I will stay aware of my surroundings and traffic"
        ),
        ChecklistItem(
            icon: "drop.fill",
            title: "Hydration",
            description: "I am properly hydrated"
        ),
        ChecklistItem(
            icon: "figure.run",
            title: "Physical Condition",
            description: "I feel physically ready to run"
        ),
        ChecklistItem(
            icon: "iphone",
            title: "Safe Usage",
            description: "I will not interact with the app while crossing streets or in hazardous areas"
        )
    ]
    
    var allChecked: Bool {
        checkedItems.count == checklistItems.count
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Safety Checklist")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Please confirm before starting your run")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                
                // Checklist
                VStack(spacing: 8) {
                    HStack {
                        Text("Check all items to continue")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(checkedItems.count)/\(checklistItems.count)")
                            .font(.caption)
                            .foregroundColor(allChecked ? .orange : .gray)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 12) {
                            ForEach(Array(checklistItems.enumerated()), id: \.offset) { index, item in
                                ChecklistRow(
                                    item: item,
                                    isChecked: checkedItems.contains(index),
                                    onToggle: {
                                        if checkedItems.contains(index) {
                                            checkedItems.remove(index)
                                        } else {
                                            checkedItems.insert(index)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                            .padding(.horizontal, 16)
                    )
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        if allChecked {
                            // Dismiss first, then execute action after a brief delay
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onContinue()
                            }
                        }
                    }) {
                        Text("Start Run")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(allChecked ? Color.orange : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!allChecked)
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

struct ChecklistItem {
    let icon: String
    let title: String
    let description: String
}

struct ChecklistRow: View {
    let item: ChecklistItem
    let isChecked: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isChecked ? .orange : .gray)
                
                HStack(spacing: 8) {
                    Image(systemName: item.icon)
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(item.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                isChecked
                    ? Color.orange.opacity(0.2)
                    : Color.white.opacity(0.05)
            )
            .cornerRadius(12)
        }
    }
}

#Preview {
    PreRunSafetyChecklistView(isPresented: .constant(true), onContinue: {})
}
