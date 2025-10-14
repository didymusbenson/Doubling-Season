//
//  CounterDatabase.swift
//  Doubling Season
//
//  Created on 10/13/25.
//

import Foundation
import SwiftUI
import Combine

/// Manages the counter database and provides search/filter functionality
/// This class loads counters from the bundled list and manages user interactions
@MainActor
class CounterDatabase: ObservableObject {
    // MARK: - Published Properties
    
    /// All counters loaded from the database
    @Published private(set) var allCounters: [CounterDefinition] = []
    
    /// Currently filtered counters based on search/filter criteria
    @Published private(set) var filteredCounters: [CounterDefinition] = []
    
    /// Current search query
    @Published var searchQuery: String = "" {
        didSet {
            filterCounters()
        }
    }
    
    /// Recently used counters (limited to last 10)
    @Published private(set) var recentCounters: [CounterDefinition] = []
    
    /// User's favorite counters
    @Published private(set) var favoriteCounters: Set<String> = []
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    /// Filter options
    @Published var showFavoritesOnly: Bool = false {
        didSet {
            filterCounters()
        }
    }
    
    @Published var showRecentsOnly: Bool = false {
        didSet {
            filterCounters()
        }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "favoriteCounters"
    private let recentsKey = "recentCounters"
    
    // MARK: - Initialization
    
    init() {
        loadFavorites()
        loadRecents()
        loadCounters()
    }
    
    // MARK: - Public Methods
    
    /// Loads all counters from the predefined list
    func loadCounters() {
        isLoading = true
        
        // Predefined list of counters from Improvements.md
        let counterNames = [
            "+1/+1", "-1/-1", "Acorn", "Aegis", "Age", "Aim", "Arrow", "Arrowhead", "Art", "Awakening", 
            "Bait", "Blaze", "Blessing", "Blight", "Blood", "Bloodline", "Bloodstain", "Book", "Bore", "Bounty", 
            "Brain", "Bribery", "Brick", "Burden", "Cage", "Carrion", "Charge", "Chip", "Chorus", "Coin", 
            "Collection", "Component", "Contested", "Corpse", "Corruption", "CRANK!", "Credit", "Croak", "Crystal", "Cube", 
            "Currency", "Day", "Death", "Defense", "Delay", "Depletion", "Descent", "Despair", "Devotion", "Discovery", 
            "Divinity", "Doom", "Dread", "Dream", "Duty", "Echo", "Egg", "Elixir", "Ember", "Energy", 
            "Enlightened", "Eon", "Eruption", "Everything", "Experience", "Eyeball", "Eyestalk", "Fade", "Fate", "Feather", 
            "Feeding", "Fellowship", "Fetch", "Filibuster", "Finality", "Flame", "Flood", "Foreshadow", "Fungus", "Funk", 
            "Fury", "Fuse", "Gem", "Ghostform", "Glass", "Globe", "Glyph", "Gold", "Growth", "Hack", 
            "Harmony", "Hatching", "Hatchling", "Healing", "Hit", "Hole", "Hone", "Hoofprint", "Hope", "Hour", 
            "Hourglass", "Hunger", "Husk", "Ice", "Impostor", "Incarnation", "Incubation", "Infection", "Influence", "Ingenuity", 
            "Intel", "Intervention", "Invitation", "Isolation", "Javelin", "Judgment", "Ki", "Kick", "Knickknack", "Knowledge", 
            "Landmark", "Level", "Loot", "Lore", "Loyalty", "Luck", "Magnet", "Manabond", "Manifestation", "Mannequin", 
            "Matrix", "Memory", "Midway", "Milk", "Mine", "Mining", "Mire", "Music", "Muster", "Necrodermis", 
            "Nest", "Net", "Night", "Oil", "Omen", "Ore", "Page", "Pain", "Palliation", "Paralyzation", 
            "Pause", "Petal", "Petrification", "Phylactery", "Phyresis", "Pin", "Plague", "Plot", "Point", "Poison", 
            "Polyp", "Pop!", "Possession", "Pressure", "Prey", "Primeval", "Punch card", "Pupa", "Quest", "Rad", 
            "Rebuilding", "Rejection", "Release", "Reprieve", "Resonance", "Rev", "Revival", "Ribbon", "Ritual", "Rope", 
            "Rust", "Scream", "Scroll", "Shell", "Shield", "Shoe", "Shred", "Shy", "Silver", "Skewer"
        ]
        
        allCounters = counterNames.map { CounterDefinition(name: $0) }
        filterCounters()
        isLoading = false
    }
    
    /// Filters counters based on current search query and filter settings
    private func filterCounters() {
        var result = allCounters
        
        // Apply search filter
        if !searchQuery.isEmpty {
            result = result.filter { counter in
                counter.name.lowercased().contains(searchQuery.lowercased())
            }
        }
        
        // Apply favorites filter
        if showFavoritesOnly {
            result = result.filter { favoriteCounters.contains($0.name) }
        }
        
        // Apply recents filter
        if showRecentsOnly {
            result = recentCounters.filter { counter in
                result.contains(counter)
            }
        } else {
            // Sort alphabetically, but prioritize favorites and recents
            result.sort { lhs, rhs in
                let lhsFavorite = favoriteCounters.contains(lhs.name)
                let rhsFavorite = favoriteCounters.contains(rhs.name)
                let lhsRecent = recentCounters.contains(lhs)
                let rhsRecent = recentCounters.contains(rhs)
                
                if lhsFavorite != rhsFavorite {
                    return lhsFavorite
                }
                if lhsRecent != rhsRecent {
                    return lhsRecent
                }
                return lhs.name < rhs.name
            }
        }
        
        filteredCounters = result
    }
    
    /// Marks a counter as recently used
    func markAsRecent(_ counter: CounterDefinition) {
        recentCounters.removeAll { $0.name == counter.name }
        recentCounters.insert(counter, at: 0)
        
        // Limit to 10 recent items
        if recentCounters.count > 10 {
            recentCounters = Array(recentCounters.prefix(10))
        }
        
        saveRecents()
        filterCounters()
    }
    
    /// Toggles favorite status for a counter
    func toggleFavorite(_ counter: CounterDefinition) {
        if favoriteCounters.contains(counter.name) {
            favoriteCounters.remove(counter.name)
        } else {
            favoriteCounters.insert(counter.name)
        }
        saveFavorites()
        filterCounters()
    }
    
    /// Creates a new custom counter
    func createCustomCounter(name: String) -> CounterDefinition {
        let counter = CounterDefinition(name: name)
        if !allCounters.contains(counter) {
            allCounters.append(counter)
            allCounters.sort { $0.name < $1.name }
        }
        markAsRecent(counter)
        return counter
    }
    
    // MARK: - Persistence
    
    private func loadFavorites() {
        if let data = userDefaults.data(forKey: favoritesKey),
           let favorites = try? JSONDecoder().decode(Set<String>.self, from: data) {
            favoriteCounters = favorites
        }
    }
    
    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteCounters) {
            userDefaults.set(data, forKey: favoritesKey)
        }
    }
    
    private func loadRecents() {
        if let data = userDefaults.data(forKey: recentsKey),
           let recents = try? JSONDecoder().decode([CounterDefinition].self, from: data) {
            recentCounters = recents
        }
    }
    
    private func saveRecents() {
        if let data = try? JSONEncoder().encode(recentCounters) {
            userDefaults.set(data, forKey: recentsKey)
        }
    }
}