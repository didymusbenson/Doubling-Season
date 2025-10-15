//
//  SplitStackView.swift
//  Doubling Season
//
//  Created on 10/13/25.
//

import SwiftUI
import SwiftData

struct SplitStackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item
    
    @State private var splitAmount: Int = 1
    @State private var tappedFirst: Bool = false
    
    var maxSplit: Int {
        max(1, item.amount - 1)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Splitting: \(item.name)")
                        .font(.headline)
                    
                    HStack {
                        Text("Current amount: \(item.amount)")
                        Spacer()
                        Text("Tapped: \(item.tapped)")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Split amount selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Number of tokens to split off:")
                        .font(.headline)
                    
                    // Slider
                    VStack {
                        Slider(
                            value: Binding(
                                get: { Double(splitAmount) },
                                set: { splitAmount = Int($0) }
                            ),
                            in: 1...Double(maxSplit),
                            step: 1
                        )
                        
                        HStack {
                            Text("1")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(maxSplit)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Manual entry
                    HStack {
                        Text("Amount:")
                        TextField(
                            "Amount",
                            value: $splitAmount,
                            format: .number
                        )
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                        .onChange(of: splitAmount) { _, newValue in
                            splitAmount = max(1, min(newValue, maxSplit))
                        }
                    }
                }
                
                Divider()
                
                // Tapped first toggle
                Toggle("Tapped First", isOn: $tappedFirst)
                    .font(.headline)
                
                Text("When enabled, tapped tokens will be moved to the new stack first.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // Preview of the split
                VStack(alignment: .leading, spacing: 12) {
                    Text("After split:")
                        .font(.headline)
                    
                    let (originalAmount, originalTapped, newAmount, newTapped) = calculateSplit()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Original Stack")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Amount: \(originalAmount)")
                            Text("Tapped: \(originalTapped)")
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("New Stack")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Amount: \(newAmount)")
                            Text("Tapped: \(newTapped)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                // Summoning sickness footnote
                if item.summoningSick > 0 {
                    Text("Note: Splitting will remove summoning sickness from both stacks.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // Split button
                Button("Split Stack") {
                    performSplit()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(splitAmount >= item.amount)
            }
            .padding()
            .navigationTitle("Split Stack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func calculateSplit() -> (originalAmount: Int, originalTapped: Int, newAmount: Int, newTapped: Int) {
        let splitAmount = self.splitAmount
        let currentTapped = item.tapped
        
        if tappedFirst {
            // Move tapped tokens to new stack first
            let newTapped = min(splitAmount, currentTapped)
            let newUntapped = splitAmount - newTapped
            let originalTapped = currentTapped - newTapped
            
            return (
                originalAmount: item.amount - splitAmount,
                originalTapped: originalTapped,
                newAmount: splitAmount,
                newTapped: newTapped
            )
        } else {
            // Move untapped tokens to new stack first
            let availableUntapped = item.amount - currentTapped
            let newUntapped = min(splitAmount, availableUntapped)
            let newTapped = splitAmount - newUntapped
            let originalTapped = currentTapped - newTapped
            
            return (
                originalAmount: item.amount - splitAmount,
                originalTapped: originalTapped,
                newAmount: splitAmount,
                newTapped: newTapped
            )
        }
    }
    
    private func performSplit() {
        let (originalAmount, originalTapped, newAmount, newTapped) = calculateSplit()
        
        // Create new item
        let newItem = item.createDuplicate()
        newItem.amount = newAmount
        newItem.tapped = newTapped
        newItem.summoningSick = 0  // Reset summoning sickness for new stack
        
        // Update original item
        item.amount = originalAmount
        item.tapped = originalTapped
        item.summoningSick = 0  // Reset summoning sickness for original stack
        
        // Insert new item into model context
        modelContext.insert(newItem)
        
        // Save the context
        do {
            try modelContext.save()
        } catch {
            print("Failed to save split: \(error)")
        }
    }
}