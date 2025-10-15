//
//  Item.swift
//  Doubling Season
//
//  Created by DBenson on 6/4/24.
//

import Foundation
import SwiftData

/// Represents a counter applied to a token with its quantity
@Model
final class TokenCounter {
    var name: String
    var amount: Int
    
    init(name: String, amount: Int = 1) {
        self.name = name
        self.amount = amount
    }
}

@Model
final class Item {
    var abilities: String
    var name: String
    var pt: String
    var colors: String
    var amount: Int
    var tapped: Int
    var summoningSick: Int = 0  // Number of tokens with summoning sickness
    var removeAlert = false
    var addAlert = false
    var untapAlert = false
    var tapAlert = false
    var counters: [TokenCounter] = []
    var plusOneCounters: Int = 0  // +1/+1 counters
    var minusOneCounters: Int = 0  // -1/-1 counters
    var createdAt: Date = Date()  // Track creation time for consistent ordering
    
    init(abilities: String, name: String, pt: String, colors: String, amount: Int, createTapped: Bool, applySummoningSickness: Bool = true) {
        
        self.abilities = abilities
        self.name = name
        self.pt = pt
        self.amount = amount
        self.tapped = createTapped ? amount : 0
        self.summoningSick = applySummoningSickness ? amount : 0  // Apply summoning sickness based on parameter
        self.colors = colors.uppercased(with: .autoupdatingCurrent)
        self.counters = []
        self.plusOneCounters = 0
        self.minusOneCounters = 0
        self.createdAt = Date()  // Set creation time
    }
    
    // MARK: - Counter Management
    
    /// Returns true if this token is an emblem
    var isEmblem: Bool {
        return name.lowercased().contains("emblem") || abilities.lowercased().contains("emblem")
    }
    
    /// Adds a regular counter to the token
    func addCounter(name: String, amount: Int = 1) {
        if let existingCounter = counters.first(where: { $0.name == name }) {
            existingCounter.amount += amount
        } else {
            counters.append(TokenCounter(name: name, amount: amount))
        }
    }
    
    /// Removes a regular counter from the token
    func removeCounter(name: String, amount: Int = 1) {
        if let existingCounter = counters.first(where: { $0.name == name }) {
            existingCounter.amount -= amount
            if existingCounter.amount <= 0 {
                counters.removeAll { $0.name == name }
            }
        }
    }
    
    /// Adds +1/+1 or -1/-1 counters with proper interaction
    func addPowerToughnessCounters(_ amount: Int) {
        if amount > 0 {
            // Adding +1/+1 counters
            if minusOneCounters > 0 {
                let reduction = min(amount, minusOneCounters)
                minusOneCounters -= reduction
                let remaining = amount - reduction
                plusOneCounters += remaining
            } else {
                plusOneCounters += amount
            }
        } else if amount < 0 {
            // Adding -1/-1 counters
            let absAmount = abs(amount)
            if plusOneCounters > 0 {
                let reduction = min(absAmount, plusOneCounters)
                plusOneCounters -= reduction
                let remaining = absAmount - reduction
                minusOneCounters += remaining
            } else {
                minusOneCounters += absAmount
            }
        }
    }
    
    /// Gets the net +1/+1 counter effect
    var netPlusOneCounters: Int {
        return plusOneCounters - minusOneCounters
    }
    
    /// Returns formatted power/toughness with counter modifications
    var formattedPowerToughness: String {
        let net = netPlusOneCounters
        if net == 0 {
            return pt
        }
        
        // Check if p/t is in "number/number" format for counter modifications
        if canBeModifiedByCounters {
            let components = pt.split(separator: "/")
            if components.count == 2,
               let power = Int(components[0]),
               let toughness = Int(components[1]) {
                let modifiedPower = power + net
                let modifiedToughness = toughness + net
                return "\(modifiedPower)/\(modifiedToughness)"
            }
        }
        
        // For non-integer p/t values, show as "[original] +x/+x"
        if net > 0 {
            return "\(pt) (+\(net)/+\(net))"
        } else {
            return "\(pt) (\(net)/\(net))"
        }
    }
    
    /// Returns true if this token's p/t can be modified by +1/+1 counters
    var canBeModifiedByCounters: Bool {
        let components = pt.split(separator: "/")
        return components.count == 2 && 
               Int(components[0]) != nil && 
               Int(components[1]) != nil
    }
    
    /// Returns true if the p/t is modified by counters (for styling)
    var isPowerToughnessModified: Bool {
        return netPlusOneCounters != 0
    }
    
    /// Creates a duplicate of this item for stack splitting
    func createDuplicate() -> Item {
        let duplicate = Item(
            abilities: abilities,
            name: name,
            pt: pt,
            colors: colors,
            amount: 0, // Amount will be set during split
            createTapped: false, // Tapped will be set during split
            applySummoningSickness: false // Summoning sickness is reset during split
        )
        
        // Copy counters
        duplicate.plusOneCounters = plusOneCounters
        duplicate.minusOneCounters = minusOneCounters
        duplicate.counters = counters.map { TokenCounter(name: $0.name, amount: $0.amount) }
        
        // Note: createdAt will be set to current time, making the duplicate appear after the original
        
        return duplicate
    }
}
