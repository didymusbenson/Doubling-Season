//
//  TokenSearchRow.swift
//  Doubling Season
//
//  Created on 10/10/25.
//

import SwiftUI

struct TokenSearchRow: View {
    // MARK: - Properties
    let token: TokenDefinition
    let isFavorite: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    
    // MARK: - State
    @State private var isPressed = false
    
    // MARK: - Body
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Color Indicators
                colorIndicators
                
                // Main Content
                VStack(alignment: .leading, spacing: 4) {
                    // Name and P/T
                    HStack {
                        Text(token.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Power/Toughness Badge
                        if !token.pt.isEmpty {
                            powerToughnessBadge
                        }
                    }
                    
                    // Type Line
                    Text(token.cleanType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Abilities Preview
                    if !token.abilities.isEmpty {
                        Text(token.abilities)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Favorite Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onToggleFavorite()
                    }
                }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundColor(isFavorite ? .yellow : .gray)
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPressed ? Color.gray.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    // MARK: - View Components
    
    private var colorIndicators: some View {
        HStack(spacing: -4) {
            if token.colors.isEmpty {
                // Colorless
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.gray, lineWidth: 1)
                    )
            } else if token.colors == "WUBRG" || token.colors == "BGRUW" {
                // All colors - show a gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.blue,
                                Color.purple,
                                Color.red,
                                Color.green
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.gray, lineWidth: 1)
                    )
            } else {
                // Individual colors
                ForEach(Array(token.colors), id: \.self) { colorChar in
                    Circle()
                        .fill(colorForMana(String(colorChar)))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                        )
                        .overlay(
                            Text(manaSymbol(for: String(colorChar)))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(textColorForMana(String(colorChar)))
                        )
                }
            }
        }
        .frame(width: 30)
    }
    
    private var powerToughnessBadge: some View {
        HStack(spacing: 2) {
            // Special handling for different P/T formats
            if token.pt.contains("/") {
                let parts = token.pt.split(separator: "/")
                if parts.count == 2 {
                    Text(String(parts[0]))
                        .font(.system(size: 14, weight: .bold))
                    Text("/")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(String(parts[1]))
                        .font(.system(size: 14, weight: .bold))
                } else {
                    Text(token.pt)
                        .font(.system(size: 14, weight: .bold))
                }
            } else {
                Text(token.pt)
                    .font(.system(size: 14, weight: .bold))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ptBadgeColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    private var ptBadgeColor: Color {
        // Color based on P/T values
        if token.pt.contains("*") {
            return Color.purple
        } else if token.pt == "0/0" {
            return Color.gray
        } else {
            // Parse P/T to determine color
            let parts = token.pt.split(separator: "/")
            if parts.count == 2,
               let power = Int(parts[0]),
               let toughness = Int(parts[1]) {
                if power >= 5 || toughness >= 5 {
                    return Color.orange
                } else if power >= 3 || toughness >= 3 {
                    return Color.blue
                } else {
                    return Color.green
                }
            }
            return Color.gray
        }
    }
    
    // MARK: - Helper Methods
    
    private func colorForMana(_ mana: String) -> Color {
        switch mana {
        case "W": return Color(red: 1.0, green: 0.98, blue: 0.94)  // Off-white
        case "U": return Color(red: 0.0, green: 0.45, blue: 0.75)   // Blue
        case "B": return Color(red: 0.15, green: 0.15, blue: 0.15)  // Black
        case "R": return Color(red: 0.95, green: 0.25, blue: 0.15)  // Red
        case "G": return Color(red: 0.0, green: 0.65, blue: 0.35)   // Green
        default: return Color.gray
        }
    }
    
    private func textColorForMana(_ mana: String) -> Color {
        switch mana {
        case "W": return .black
        case "U": return .white
        case "B": return .white
        case "R": return .white
        case "G": return .white
        default: return .black
        }
    }
    
    private func manaSymbol(for mana: String) -> String {
        switch mana {
        case "W": return "W"
        case "U": return "U"
        case "B": return "B"
        case "R": return "R"
        case "G": return "G"
        default: return "C"
        }
    }
}

// MARK: - Preview Provider

struct TokenSearchRow_Previews: PreviewProvider {
    static var sampleTokens: [TokenDefinition] {
        [
            TokenDefinition(
                name: "Soldier",
                abilities: "Vigilance",
                pt: "1/1",
                colors: "W",
                type: "Token Creature — Soldier"
            ),
            TokenDefinition(
                name: "Zombie",
                abilities: "",
                pt: "2/2",
                colors: "B",
                type: "Token Creature — Zombie"
            ),
            TokenDefinition(
                name: "Elemental",
                abilities: "Trample, haste",
                pt: "4/4",
                colors: "RG",
                type: "Token Creature — Elemental"
            ),
            TokenDefinition(
                name: "Treasure",
                abilities: "{T}, Sacrifice this artifact: Add one mana of any color.",
                pt: "",
                colors: "",
                type: "Token Artifact — Treasure"
            ),
            TokenDefinition(
                name: "Angel",
                abilities: "Flying, vigilance, lifelink",
                pt: "4/4",
                colors: "W",
                type: "Token Creature — Angel"
            ),
            TokenDefinition(
                name: "Dragon",
                abilities: "Flying\nWhenever this creature attacks, it deals 2 damage to any target.",
                pt: "5/5",
                colors: "R",
                type: "Token Creature — Dragon"
            ),
            TokenDefinition(
                name: "Saproling",
                abilities: "",
                pt: "1/1",
                colors: "G",
                type: "Token Creature — Saproling"
            ),
            TokenDefinition(
                name: "Construct",
                abilities: "This creature gets +1/+1 for each artifact you control.",
                pt: "*/*",
                colors: "",
                type: "Token Artifact Creature — Construct"
            )
        ]
    }
    
    static var previews: some View {
        NavigationView {
            List {
                ForEach(sampleTokens) { token in
                    TokenSearchRow(
                        token: token,
                        isFavorite: token.name == "Angel" || token.name == "Dragon",
                        onTap: {
                            print("Tapped: \(token.name)")
                        },
                        onToggleFavorite: {
                            print("Toggle favorite: \(token.name)")
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                }
            }
            .navigationTitle("Token Search")
            .listStyle(PlainListStyle())
        }
        .previewDisplayName("Token List")
        
        // Single row previews
        VStack(spacing: 20) {
            TokenSearchRow(
                token: sampleTokens[0],
                isFavorite: false,
                onTap: {},
                onToggleFavorite: {}
            )
            
            TokenSearchRow(
                token: sampleTokens[2],
                isFavorite: true,
                onTap: {},
                onToggleFavorite: {}
            )
            
            TokenSearchRow(
                token: sampleTokens[3],
                isFavorite: false,
                onTap: {},
                onToggleFavorite: {}
            )
            
            TokenSearchRow(
                token: sampleTokens[7],
                isFavorite: true,
                onTap: {},
                onToggleFavorite: {}
            )
        }
        .padding()
        .previewDisplayName("Individual Rows")
    }
}
