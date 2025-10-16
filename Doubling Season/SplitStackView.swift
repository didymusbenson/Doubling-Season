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
    var onSplitCompleted: (() -> Void)?
    
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

                    HStack {
                        Button(action: {
                            if splitAmount > 1 {
                                splitAmount -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(splitAmount > 1 ? .blue : .gray)
                        }
                        .disabled(splitAmount <= 1)

                        Spacer()

                        TextField("Amount", value: $splitAmount, format: .number)
                            .font(.title)
                            .fontWeight(.bold)
                            .frame(minWidth: 50)
                            .multilineTextAlignment(.center)
                            .onChange(of: splitAmount) { _, newValue in
                                // Ensure amount is within valid range
                                splitAmount = max(1, min(newValue, maxSplit))
                            }

                        Spacer()

                        Button(action: {
                            if splitAmount < maxSplit {
                                splitAmount += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(splitAmount < maxSplit ? .blue : .gray)
                        }
                        .disabled(splitAmount >= maxSplit)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
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
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        performSplit()
                        onSplitCompleted?()
                    }
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
        .onAppear {
            // Initialize splitAmount based on maxSplit to prevent crashes
            if splitAmount > maxSplit {
                splitAmount = max(1, maxSplit)
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