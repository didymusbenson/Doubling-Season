//
//  TokenDefinition.swift
//  Doubling Season
//
//  Created on 10/10/25.
//

import Foundation
import SwiftData

/// Represents a token definition from the TokenDatabase.json file
/// This struct is used to decode and work with token data in the app
struct TokenDefinition: Codable, Identifiable, Hashable {
    // MARK: - Properties
    
    /// The name of the token
    let name: String
    
    /// The abilities text of the token
    let abilities: String
    
    /// The power/toughness of the token (e.g., "2/2", "*/*")
    let pt: String
    
    /// The color identity of the token (e.g., "W", "UB", "WUBRG")
    let colors: String
    
    /// The type line of the token (e.g., "Token Creature — Zombie")
    let type: String
    
    // MARK: - Identifiable

    /// Unique identifier for SwiftUI list operations
    var id: String {
        // Create a composite ID to handle tokens with the same name but different stats/abilities
        return "\(name)|\(pt)|\(colors)|\(type)|\(abilities)"
    }
    
    // MARK: - Computed Properties
    
    /// Searchable text that combines all relevant fields for search functionality
    var searchableText: String {
        // Combine all text fields for comprehensive search
        return "\(name) \(abilities) \(type) \(colors) \(pt)".lowercased()
    }
    
    /// Returns true if this token is a creature (has power/toughness)
    var isCreature: Bool {
        return !pt.isEmpty
    }
    
    /// Returns a formatted color string for display
    var colorDisplay: String {
        if colors.isEmpty {
            return "Colorless"
        } else if colors.count == 1 {
            switch colors {
            case "W": return "White"
            case "U": return "Blue"
            case "B": return "Black"
            case "R": return "Red"
            case "G": return "Green"
            default: return colors
            }
        } else if colors == "WUBRG" || colors == "BGRUW" {
            return "All Colors"
        } else {
            // Multi-color
            return "Multicolor (\(colors))"
        }
    }
    
    /// Returns a clean type string without "Token" prefix
    var cleanType: String {
        if type.hasPrefix("Token ") {
            return String(type.dropFirst(6))
        }
        return type
    }
    
    // MARK: - Methods
    
    /// Converts this TokenDefinition to an Item for creation in the game
    /// - Parameters:
    ///   - amount: The number of tokens to create
    ///   - createTapped: Whether the tokens should enter tapped
    /// - Returns: An Item instance ready to be added to the game
    func toItem(amount: Int = 1, createTapped: Bool = false) -> Item {
        return Item(
            abilities: abilities,
            name: name,
            pt: pt,
            colors: colors,
            amount: amount,
            createTapped: createTapped
        )
    }
    
    /// Checks if this token matches a search query
    /// - Parameter query: The search string to match against
    /// - Returns: true if the token matches the search query
    func matches(searchQuery query: String) -> Bool {
        if query.isEmpty {
            return true
        }
        
        let lowercasedQuery = query.lowercased()
        
        // Check for exact matches in important fields
        if name.lowercased().contains(lowercasedQuery) {
            return true
        }
        
        // Check searchable text for partial matches
        return searchableText.contains(lowercasedQuery)
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: TokenDefinition, rhs: TokenDefinition) -> Bool {
        return lhs.name == rhs.name
    }
}

// MARK: - Extensions

extension TokenDefinition {
    /// Common token categories for filtering
    enum Category: String, CaseIterable {
        case creature = "Creature"
        case artifact = "Artifact"
        case enchantment = "Enchantment"
        case emblem = "Emblem"
        case dungeon = "Dungeon"
        case counter = "Counter"
        case other = "Other"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    /// Returns the primary category of this token
    var category: Category {
        let typeLC = type.lowercased()
        
        if typeLC.contains("emblem") {
            return .emblem
        } else if typeLC.contains("dungeon") {
            return .dungeon
        } else if typeLC.contains("counter") {
            return .counter
        } else if typeLC.contains("creature") {
            return .creature
        } else if typeLC.contains("artifact") {
            return .artifact
        } else if typeLC.contains("enchantment") {
            return .enchantment
        } else {
            return .other
        }
    }
}