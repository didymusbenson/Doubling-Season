//
//  Item.swift
//  Doubling Season
//
//  Created by DBenson on 6/4/24.
//

import Foundation
import SwiftData

@Model
final class Item : Codable{
    var abilities: String
    var name: String
    var pt: String
    var colors: String
    var amount: Int
    var tapped: Int
    var removeAlert = false
    var addAlert = false
    var untapAlert = false
    var tapAlert = false
    
    init(abilities: String, name: String, pt: String, colors: String, amount: Int, createTapped: Bool) {
        
        self.abilities = abilities
        self.name = name
        self.pt = pt
        self.amount = amount
        self.tapped = createTapped ? amount : 0
        self.colors = colors.uppercased(with: .autoupdatingCurrent)
    }

    // New initializer for decoding from Decoder
    init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            abilities = try container.decode(String.self, forKey: .abilities)
            name = try container.decode(String.self, forKey: .name)
            pt = try container.decode(String.self, forKey: .pt)
            colors = try container.decode(String.self, forKey: .colors)
            amount = try container.decode(Int.self, forKey: .amount)
            tapped = try container.decode(Int.self, forKey: .tapped)
        
        // Process colors if needed (e.g., uppercasing)
        colors = colors.uppercased(with: .autoupdatingCurrent)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(abilities, forKey: .abilities)
        try container.encode(name, forKey: .name)
        try container.encode(pt, forKey: .pt)
        try container.encode(colors, forKey: .colors)
        try container.encode(amount, forKey: .amount)
        try container.encode(tapped, forKey: .tapped)
    }
    
    private enum CodingKeys: String, CodingKey {
            case abilities
            case name
            case pt
            case colors
            case amount
            case tapped
            case removeAlert
            case addAlert
            case untapAlert
            case tapAlert
    }
}
