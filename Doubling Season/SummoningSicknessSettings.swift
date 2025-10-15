//
//  SummoningSicknessSettings.swift
//  Doubling Season
//
//  Created on 10/14/25.
//

import Foundation

/// Manages the summoning sickness feature state within a session
/// This setting does not persist between app launches
class SummoningSicknessSettings: ObservableObject {
    @Published var isEnabled: Bool = true
    
    static let shared = SummoningSicknessSettings()
    
    private init() {}
}