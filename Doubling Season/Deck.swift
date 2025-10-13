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
    
    var templates: [TokenTemplate] {
        get {
            guard let data = templatesData else { return [] }
            return (try? JSONDecoder().decode([TokenTemplate].self, from: data)) ?? []
        }
        set {
            templatesData = try? JSONEncoder().encode(newValue)
        }
    }
    
    init(name: String, templates: [TokenTemplate] = []) {
        self.name = name
        self.templates = templates
    }
}
