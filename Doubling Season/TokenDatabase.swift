//
//  TokenDatabase.swift
//  Doubling Season
//
//  Created on 10/10/25.
//

import Foundation
import SwiftUI
import Combine

/// Manages the token database and provides search/filter functionality
/// This class loads tokens from the bundled JSON and manages user interactions
@MainActor
class TokenDatabase: ObservableObject {
    // MARK: - Published Properties
    
    /// All tokens loaded from the database
    @Published private(set) var allTokens: [TokenDefinition] = []
    
    /// Currently filtered tokens based on search/filter criteria
    @Published private(set) var filteredTokens: [TokenDefinition] = []
    
    /// Current search query
    @Published var searchQuery: String = "" {
        didSet {
            filterTokens()
        }
    }
    
    /// Currently selected category filter
    @Published var selectedCategory: TokenDefinition.Category? = nil {
        didSet {
            filterTokens()
        }
    }
    
    /// Recently viewed tokens (limited to last 10)
    @Published private(set) var recentTokens: [TokenDefinition] = []
    
    /// User's favorite tokens
    @Published private(set) var favoriteTokens: Set<String> = []
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    /// Error message if loading fails
    @Published private(set) var loadError: String? = nil
    
    // MARK: - Private Properties
    
    /// Maximum number of recent tokens to track
    private let maxRecentTokens = 10
    
    /// UserDefaults keys for persistence
    private enum UserDefaultsKeys {
        static let recentTokenNames = "recentTokenNames"
        static let favoriteTokenNames = "favoriteTokenNames"
    }
    
    // MARK: - Initialization
    
    init() {
        loadUserPreferences()
        Task {
            await loadTokens()
        }
    }
    
    // MARK: - Public Methods
    
    /// Loads tokens from the bundled JSON file
    func loadTokens() async {
        isLoading = true
        loadError = nil
        
        do {
            // Get the URL for the bundled JSON file
            guard let url = Bundle.main.url(forResource: "TokenDatabase", withExtension: "json") else {
                throw TokenDatabaseError.fileNotFound
            }
            
            // Load the data
            let data = try Data(contentsOf: url)
            
            // Decode the tokens
            let decoder = JSONDecoder()
            let tokens = try decoder.decode([TokenDefinition].self, from: data)
            
            // Update on main thread
            await MainActor.run {
                self.allTokens = tokens
                self.filteredTokens = tokens
                self.isLoading = false
                
                print("Successfully loaded \(tokens.count) tokens")
            }
            
        } catch {
            await MainActor.run {
                self.loadError = "Failed to load tokens: \(error.localizedDescription)"
                self.isLoading = false
                self.allTokens = []
                self.filteredTokens = []
                
                print("Error loading tokens: \(error)")
            }
        }
    }
    
    /// Filters tokens based on current search query and category
    func filterTokens() {
        var results = allTokens
        
        // Apply search query filter
        if !searchQuery.isEmpty {
            results = results.filter { token in
                token.matches(searchQuery: searchQuery)
            }
        }
        
        // Apply category filter
        if let category = selectedCategory {
            results = results.filter { token in
                token.category == category
            }
        }
        
        // Sort results alphabetically
        results.sort { $0.name < $1.name }
        
        filteredTokens = results
    }
    
    /// Clears all filters and shows all tokens
    func clearFilters() {
        searchQuery = ""
        selectedCategory = nil
        filteredTokens = allTokens
    }
    
    /// Adds a token to the recent tokens list
    /// - Parameter token: The token that was recently viewed/used
    func addToRecent(_ token: TokenDefinition) {
        // Remove if already exists to avoid duplicates
        recentTokens.removeAll { $0.id == token.id }
        
        // Add to beginning
        recentTokens.insert(token, at: 0)
        
        // Limit to max recent tokens
        if recentTokens.count > maxRecentTokens {
            recentTokens = Array(recentTokens.prefix(maxRecentTokens))
        }
        
        // Save to UserDefaults
        saveRecentTokens()
    }
    
    /// Toggles a token's favorite status
    /// - Parameter token: The token to toggle
    func toggleFavorite(_ token: TokenDefinition) {
        if favoriteTokens.contains(token.id) {
            favoriteTokens.remove(token.id)
        } else {
            favoriteTokens.insert(token.id)
        }
        
        // Save to UserDefaults
        saveFavoriteTokens()
    }
    
    /// Checks if a token is marked as favorite
    /// - Parameter token: The token to check
    /// - Returns: true if the token is a favorite
    func isFavorite(_ token: TokenDefinition) -> Bool {
        return favoriteTokens.contains(token.id)
    }
    
    /// Returns favorite tokens as an array
    /// - Returns: Array of favorite TokenDefinitions
    func getFavoriteTokens() -> [TokenDefinition] {
        return allTokens.filter { favoriteTokens.contains($0.id) }
            .sorted { $0.name < $1.name }
    }
    
    /// Searches for tokens by name with fuzzy matching
    /// - Parameter name: The name to search for
    /// - Returns: Array of matching tokens
    func searchByName(_ name: String) -> [TokenDefinition] {
        guard !name.isEmpty else { return allTokens }
        
        let lowercasedName = name.lowercased()
        
        // First, try exact matches
        let exactMatches = allTokens.filter { 
            $0.name.lowercased() == lowercasedName 
        }
        
        if !exactMatches.isEmpty {
            return exactMatches
        }
        
        // Then, try prefix matches
        let prefixMatches = allTokens.filter { 
            $0.name.lowercased().hasPrefix(lowercasedName) 
        }
        
        if !prefixMatches.isEmpty {
            return prefixMatches.sorted { $0.name < $1.name }
        }
        
        // Finally, try contains matches
        return allTokens.filter { 
            $0.name.lowercased().contains(lowercasedName) 
        }.sorted { $0.name < $1.name }
    }
    
    /// Gets tokens by category
    /// - Parameter category: The category to filter by
    /// - Returns: Array of tokens in the specified category
    func getTokensByCategory(_ category: TokenDefinition.Category) -> [TokenDefinition] {
        return allTokens.filter { $0.category == category }
            .sorted { $0.name < $1.name }
    }
    
    /// Gets token statistics
    /// - Returns: Dictionary with various statistics about the token database
    func getStatistics() -> [String: Any] {
        return [
            "totalTokens": allTokens.count,
            "creatures": allTokens.filter { $0.isCreature }.count,
            "nonCreatures": allTokens.filter { !$0.isCreature }.count,
            "colorless": allTokens.filter { $0.colors.isEmpty }.count,
            "multicolor": allTokens.filter { $0.colors.count > 1 }.count,
            "favorites": favoriteTokens.count,
            "recent": recentTokens.count
        ]
    }
    
    // MARK: - Private Methods
    
    /// Loads user preferences from UserDefaults
    private func loadUserPreferences() {
        // Load recent tokens
        if let recentNames = UserDefaults.standard.array(forKey: UserDefaultsKeys.recentTokenNames) as? [String] {
            // Will be populated after tokens are loaded
            Task {
                await loadRecentTokensFromNames(recentNames)
            }
        }
        
        // Load favorite tokens
        if let favoriteNames = UserDefaults.standard.array(forKey: UserDefaultsKeys.favoriteTokenNames) as? [String] {
            favoriteTokens = Set(favoriteNames)
        }
    }
    
    /// Loads recent tokens from saved names
    private func loadRecentTokensFromNames(_ names: [String]) async {
        // Wait for tokens to be loaded
        while allTokens.isEmpty && !loadError.hasValue {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Map names to tokens
        let tokens = names.compactMap { name in
            allTokens.first { $0.name == name }
        }
        
        await MainActor.run {
            self.recentTokens = tokens
        }
    }
    
    /// Saves recent tokens to UserDefaults
    private func saveRecentTokens() {
        let names = recentTokens.map { $0.name }
        UserDefaults.standard.set(names, forKey: UserDefaultsKeys.recentTokenNames)
    }
    
    /// Saves favorite tokens to UserDefaults
    private func saveFavoriteTokens() {
        let names = Array(favoriteTokens)
        UserDefaults.standard.set(names, forKey: UserDefaultsKeys.favoriteTokenNames)
    }
}

// MARK: - Error Types

enum TokenDatabaseError: LocalizedError {
    case fileNotFound
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "TokenDatabase.json file not found in bundle"
        case .decodingError(let error):
            return "Failed to decode tokens: \(error.localizedDescription)"
        }
    }
}

// MARK: - Helper Extensions

private extension Optional where Wrapped == String {
    var hasValue: Bool {
        return self != nil
    }
}