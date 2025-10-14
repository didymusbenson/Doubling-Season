//
//  CounterSearchView.swift
//  Doubling Season
//
//  Created on 10/13/25.
//

import SwiftUI
import SwiftData

struct CounterSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var counterDatabase = CounterDatabase()
    @Bindable var item: Item
    
    @State private var selectedAmount = 1
    @State private var showStackSplitChoice = false
    @State private var selectedCounter: CounterDefinition?
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search counters...", text: $counterDatabase.searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Filter options
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        FilterButton(
                            title: "All",
                            isSelected: !counterDatabase.showFavoritesOnly && !counterDatabase.showRecentsOnly
                        ) {
                            counterDatabase.showFavoritesOnly = false
                            counterDatabase.showRecentsOnly = false
                        }
                        
                        FilterButton(
                            title: "Favorites",
                            isSelected: counterDatabase.showFavoritesOnly
                        ) {
                            counterDatabase.showFavoritesOnly.toggle()
                            if counterDatabase.showFavoritesOnly {
                                counterDatabase.showRecentsOnly = false
                            }
                        }
                        
                        FilterButton(
                            title: "Recent",
                            isSelected: counterDatabase.showRecentsOnly
                        ) {
                            counterDatabase.showRecentsOnly.toggle()
                            if counterDatabase.showRecentsOnly {
                                counterDatabase.showFavoritesOnly = false
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Amount stepper
                HStack {
                    Text("Amount:")
                    Stepper(value: $selectedAmount, in: 1...99) {
                        Text("\(selectedAmount)")
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // Counter list
                if counterDatabase.filteredCounters.isEmpty && !counterDatabase.searchQuery.isEmpty {
                    // No results found
                    VStack(spacing: 16) {
                        Text("No counters found for '\(counterDatabase.searchQuery)'")
                            .foregroundColor(.secondary)
                        
                        Button("Create '\(counterDatabase.searchQuery)' counter") {
                            let newCounter = counterDatabase.createCustomCounter(name: counterDatabase.searchQuery)
                            selectCounter(newCounter)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(counterDatabase.filteredCounters) { counter in
                        CounterRowView(
                            counter: counter,
                            isFavorite: counterDatabase.favoriteCounters.contains(counter.name)
                        ) {
                            selectCounter(counter)
                        } onFavoriteToggle: {
                            counterDatabase.toggleFavorite(counter)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Add Counter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Add Counter", isPresented: $showStackSplitChoice) {
            Button("To All Tokens") {
                if let counter = selectedCounter {
                    addCounterToStack(counter, splitStack: false)
                }
            }
            
            Button("To One Token") {
                if let counter = selectedCounter {
                    addCounterToStack(counter, splitStack: true)
                }
            }
            
            Button("Cancel", role: .cancel) {
                selectedCounter = nil
            }
        } message: {
            Text("Do you want to add this counter to all tokens in the stack, or split the stack and add it to one token?")
        }
    }
    
    private func selectCounter(_ counter: CounterDefinition) {
        selectedCounter = counter
        counterDatabase.markAsRecent(counter)
        
        // Handle special +1/+1 and -1/-1 counters
        if counter.name == "+1/+1" || counter.name == "-1/-1" {
            let amount = counter.name == "+1/+1" ? selectedAmount : -selectedAmount
            item.addPowerToughnessCounters(amount)
            dismiss()
        } else {
            // For regular counters, show stack split choice
            showStackSplitChoice = true
        }
    }
    
    private func addCounterToStack(_ counter: CounterDefinition, splitStack: Bool) {
        if splitStack && item.amount > 1 {
            // Split stack and add counter to new token
            let newItem = item.createDuplicate()
            newItem.amount = 1
            newItem.tapped = item.tapped > 0 ? 1 : 0
            
            // Reduce original stack
            item.amount -= 1
            if item.tapped > 0 {
                item.tapped -= 1
            }
            
            // Add counter to new token
            newItem.addCounter(name: counter.name, amount: selectedAmount)
            
            // Insert new token into the model context
            modelContext.insert(newItem)
        } else {
            // Add to existing stack
            item.addCounter(name: counter.name, amount: selectedAmount)
        }
        
        selectedCounter = nil
        dismiss()
    }
}

// MARK: - Counter Row View

struct CounterRowView: View {
    let counter: CounterDefinition
    let isFavorite: Bool
    let onSelect: () -> Void
    let onFavoriteToggle: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(counter.name)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Button(action: onFavoriteToggle) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundColor(isFavorite ? .yellow : .gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}