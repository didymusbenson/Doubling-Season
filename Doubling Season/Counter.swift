//
//  Counter.swift
//  Doubling Season
//
//  Created on 10/13/25.
//

import Foundation
import SwiftData

/// Represents a counter definition from the CounterDatabase
struct CounterDefinition: Codable, Identifiable, Hashable {
    let name: String
    let color: String
    
    var id: String { name }
    
    init(name: String, color: String = "default") {
        self.name = name
        self.color = color
    }
}