//
//  Deck.swift
//  Doubling Season
//
//  Created by DBenson on 6/4/24.
//

import Foundation
import SwiftData

// Plain struct for deck templates - NOT a SwiftData model
struct TokenTemplate: Codable {
    let abilities: String
    let name: String
    let pt: String
    let colors: String
    
    // Convert from Item to template
    init(from item: Item) {
        self.abilities = item.abilities
        self.name = item.name
        self.pt = item.pt
        self.colors = item.colors
    }
    
    // Create Item from template
    func createItem(amount: Int = 1, tapped: Bool = false) -> Item {
        return Item(
            abilities: abilities,
            name: name,
            pt: pt,
            colors: colors,
            amount: amount,
            createTapped: tapped
        )
    }
}

@Model
final class Deck {
    var name: String
    var templatesData: Data? // Store templates as JSON data

    /// Returns the decoded token templates, or empty array if data is nil or decode fails
    var templates: [TokenTemplate] {
        get {
            guard let data = templatesData else { return [] }

            do {
                return try JSONDecoder().decode([TokenTemplate].self, from: data)
            } catch {
                print("⚠️ Failed to decode deck '\(name)' templates: \(error.localizedDescription)")
                // Return empty array rather than crash - data may be corrupted
                return []
            }
        }
        set {
            do {
                templatesData = try JSONEncoder().encode(newValue)
            } catch {
                // This should never happen with TokenTemplate (it's Codable), but log if it does
                print("🚨 CRITICAL: Failed to encode deck '\(name)' templates: \(error.localizedDescription)")
                // Leave templatesData unchanged to preserve existing data
            }
        }
    }

    init(name: String, templates: [TokenTemplate] = []) {
        // Ensure deck has a name
        self.name = name.isEmpty ? "Untitled Deck" : name
        // Use setter which handles encoding
        self.templates = templates
    }
}
