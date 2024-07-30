//
//  Item.swift
//  Doubling Season
//
//  Created by DBenson on 6/4/24.
//

import Foundation
import SwiftData

@Model
final class Item {
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
}
