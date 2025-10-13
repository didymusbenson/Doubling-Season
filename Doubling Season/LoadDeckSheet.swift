//
//  LoadDeckSheet.swift
//  Doubling Season
//
//  Created by DBenson on 10/10/25.
//


import SwiftUI
import SwiftData

struct LoadDeckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var decks: [Deck]
    @Query private var items: [Item]
    
    @State private var selectedDeck: Deck?
    @State private var showDeleteConfirmation = false
    @State private var deckToDelete: Deck?
    
    var body: some View {
        NavigationView {
            VStack {
                if decks.isEmpty {
                    Text("No saved decks")
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(decks, id: \.name) { deck in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(deck.name)
                                        .font(.headline)
                                    Text(deck.templates.isEmpty ? "No tokens" :
                                         deck.templates.count == 1 ? deck.templates[0].name :
                                         "\(deck.templates[0].name) and \(deck.templates.count - 1) other tokens")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedDeck == deck {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDeck = deck
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    deckToDelete = deck
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Load Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Load") {
                        if let deck = selectedDeck {
                            loadDeck(deck)
                            dismiss()
                        }
                    }
                    .disabled(selectedDeck == nil)
                }
            }
            .alert("Delete Deck?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let deck = deckToDelete {
                        modelContext.delete(deck)
                        if selectedDeck == deck {
                            selectedDeck = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the deck '\(deckToDelete?.name ?? "")'")
            }
        }
    }
    
    private func loadDeck(_ deck: Deck) {
        // Clear current items
        items.forEach { item in
            modelContext.delete(item)
        }
        
        // Create new items from templates
        deck.templates.forEach { template in
            let newItem = template.createItem(amount: 0, tapped: false)
            modelContext.insert(newItem)
        }
        
        // Save context
        do {
            try modelContext.save()
        } catch {
            print("Failed to load deck: \(error)")
        }
    }
}
