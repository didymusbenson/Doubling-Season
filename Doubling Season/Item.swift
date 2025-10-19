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
    // MARK: - Basic Properties

    var abilities: String
    var name: String
    var pt: String

    var colors: String {
        didSet {
            colors = colors.uppercased()
        }
    }

    // MARK: - Amount and State (with validation)

    /// Total number of tokens in this stack
    var amount: Int {
        didSet {
            // Ensure non-negative
            if amount < 0 { amount = 0 }

            // Auto-correct dependent values when amount decreases
            if tapped > amount { tapped = amount }
            if summoningSick > amount { summoningSick = amount }
        }
    }

    /// Number of tapped tokens
    var tapped: Int {
        didSet {
            // Clamp tapped to valid range [0, amount]
            if tapped < 0 { tapped = 0 }
            if tapped > amount { tapped = amount }
        }
    }

    /// Number of tokens with summoning sickness
    var summoningSick: Int = 0 {
        didSet {
            // Clamp summoning sick to valid range [0, amount]
            if summoningSick < 0 { summoningSick = 0 }
            if summoningSick > amount { summoningSick = amount }
        }
    }

    // MARK: - Counters

    var counters: [TokenCounter] = []

    /// +1/+1 counters on this token
    var plusOneCounters: Int = 0 {
        didSet {
            if plusOneCounters < 0 { plusOneCounters = 0 }
        }
    }

    /// -1/-1 counters on this token
    var minusOneCounters: Int = 0 {
        didSet {
            if minusOneCounters < 0 { minusOneCounters = 0 }
        }
    }

    // MARK: - Metadata

    /// Track creation time for consistent ordering
    var createdAt: Date = Date()

    // MARK: - Initialization

    init(abilities: String, name: String, pt: String, colors: String, amount: Int, createTapped: Bool, applySummoningSickness: Bool = true) {
        self.abilities = abilities
        self.name = name
        self.pt = pt

        // Initialize with validation
        let safeAmount = max(0, amount)
        self.amount = safeAmount
        self.tapped = createTapped ? safeAmount : 0
        self.summoningSick = applySummoningSickness ? safeAmount : 0
        self.colors = colors.uppercased()
    }
    
    // MARK: - Counter Management
    
    /// Returns true if this token is an emblem
    var isEmblem: Bool {
        return name.lowercased().contains("emblem") || abilities.lowercased().contains("emblem")
    }
    
    /// Adds a regular counter to the token
    /// - Parameters:
    ///   - name: Name of the counter to add
    ///   - amount: Number of counters to add
    /// - Returns: true if counter was added successfully, false if validation failed
    @discardableResult
    func addCounter(name: String, amount: Int = 1) -> Bool {
        guard !name.isEmpty, amount > 0 else { return false }

        if let existingCounter = counters.first(where: { $0.name == name }) {
            existingCounter.amount += amount
        } else {
            counters.append(TokenCounter(name: name, amount: amount))
        }
        return true
    }

    /// Removes a regular counter from the token
    /// - Parameters:
    ///   - name: Name of the counter to remove
    ///   - amount: Number of counters to remove
    /// - Returns: true if counter was found and removed, false if counter not found
    @discardableResult
    func removeCounter(name: String, amount: Int = 1) -> Bool {
        guard let existingCounter = counters.first(where: { $0.name == name }) else {
            return false
        }

        existingCounter.amount -= amount
        if existingCounter.amount <= 0 {
            counters.removeAll { $0.name == name }
        }
        return true
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

// MARK: - Color Identity Extension

import SwiftUI

extension Item {
    /// Represents Magic: The Gathering color identity using OptionSet for type-safe color handling
    struct ColorIdentity: OptionSet, Codable {
        let rawValue: Int

        static let white = ColorIdentity(rawValue: 1 << 0)
        static let blue = ColorIdentity(rawValue: 1 << 1)
        static let black = ColorIdentity(rawValue: 1 << 2)
        static let red = ColorIdentity(rawValue: 1 << 3)
        static let green = ColorIdentity(rawValue: 1 << 4)

        static let colorless: ColorIdentity = []

        init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Parse from WUBRG string (e.g., "WUB" for White-Blue-Black)
        /// - Parameter wubrgString: Color string using Magic color notation
        init(from wubrgString: String) {
            var result: ColorIdentity = []
            if wubrgString.contains("W") { result.insert(.white) }
            if wubrgString.contains("U") { result.insert(.blue) }
            if wubrgString.contains("B") { result.insert(.black) }
            if wubrgString.contains("R") { result.insert(.red) }
            if wubrgString.contains("G") { result.insert(.green) }
            self = result
        }

        /// Convert to WUBRG string in canonical order
        var wubrgString: String {
            var result = ""
            if contains(.white) { result += "W" }
            if contains(.blue) { result += "U" }
            if contains(.black) { result += "B" }
            if contains(.red) { result += "R" }
            if contains(.green) { result += "G" }
            return result
        }

        /// Returns SwiftUI colors for display (gradient borders, etc.)
        var swiftUIColors: [Color] {
            var colors: [Color] = []
            if contains(.white) { colors.append(.yellow) }
            if contains(.blue) { colors.append(.blue) }
            if contains(.black) { colors.append(.purple) }
            if contains(.red) { colors.append(.red) }
            if contains(.green) { colors.append(.green) }
            return colors.isEmpty ? [.gray] : colors
        }

        /// User-friendly display name for the color identity
        var displayName: String {
            if isEmpty {
                return "Colorless"
            } else if self == [.white, .blue, .black, .red, .green] {
                return "All Colors"
            } else if rawValue.nonzeroBitCount == 1 {
                // Single color
                if contains(.white) { return "White" }
                if contains(.blue) { return "Blue" }
                if contains(.black) { return "Black" }
                if contains(.red) { return "Red" }
                if contains(.green) { return "Green" }
            }
            // Multicolor
            return "Multicolor (\(wubrgString))"
        }
    }

    /// Computed property for type-safe color access
    /// Allows working with colors as a structured type while maintaining String storage
    var colorIdentity: ColorIdentity {
        get { ColorIdentity(from: colors) }
        set { colors = newValue.wubrgString }
    }
}
