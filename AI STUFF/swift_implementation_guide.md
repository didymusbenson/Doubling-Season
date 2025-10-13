# Swift Implementation Guide for Token Search

## 1. Token Data Model (`TokenDefinition.swift`)

```swift
//
//  TokenDefinition.swift
//  Doubling Season
//
//  Token definition model for the searchable database
//

import Foundation
import SwiftUI

// MARK: - Token Definition Model

struct TokenDefinition: Codable, Identifiable, Hashable {
    // Use name + colors + pt as a composite ID since tokens can have same names
    var id: String {
        "\(name)-\(colors)-\(pt)"
    }
    
    let name: String
    let abilities: String
    let pt: String
    let colors: String
    let type: String
    
    // Computed property for search functionality
    var searchableText: String {
        "\(name.lowercased()) \(abilities.lowercased()) \(type.lowercased()) \(pt)"
    }
    
    // Helper to get color array for display
    var colorArray: [Character] {
        Array(colors)
    }
    
    // Check if token matches search query
    func matches(query: String) -> Bool {
        if query.isEmpty { return true }
        let lowercaseQuery = query.lowercased()
        
        // Check multiple fields
        if name.lowercased().contains(lowercaseQuery) { return true }
        if abilities.lowercased().contains(lowercaseQuery) { return true }
        if type.lowercased().contains(lowercaseQuery) { return true }
        if pt.contains(query) { return true }
        
        return false
    }
    
    // Convert to Item for creation
    func toItem(amount: Int, createTapped: Bool) -> Item {
        return Item(
            abilities: abilities,
            name: name,
            pt: pt,
            colors: colors,
            amount: amount,
            createTapped: createTapped
        )
    }
}

// MARK: - Token Categories

enum TokenCategory: String, CaseIterable {
    case creature = "Creature"
    case artifact = "Artifact"
    case enchantment = "Enchantment"
    case land = "Land"
    case planeswalker = "Planeswalker"
    
    var icon: String {
        switch self {
        case .creature: return "hare.fill"
        case .artifact: return "gear"
        case .enchantment: return "sparkles"
        case .land: return "mountain.2.fill"
        case .planeswalker: return "person.fill"
        }
    }
    
    static func from(type: String) -> TokenCategory {
        let lowercaseType = type.lowercased()
        for category in TokenCategory.allCases {
            if lowercaseType.contains(category.rawValue.lowercased()) {
                return category
            }
        }
        return .creature // Default
    }
}

// MARK: - Token Database Manager

class TokenDatabase: ObservableObject {
    @Published var allTokens: [TokenDefinition] = []
    @Published var filteredTokens: [TokenDefinition] = []
    @Published var recentTokens: [String] = [] // Store recent token IDs
    @Published var favoriteTokens: Set<String> = [] // Store favorite token IDs
    @Published var isLoading = false
    @Published var searchQuery = ""
    
    private let recentTokensKey = "RecentTokens"
    private let favoriteTokensKey = "FavoriteTokens"
    private let maxRecentTokens = 10
    
    init() {
        loadTokens()
        loadUserPreferences()
    }
    
    // MARK: - Data Loading
    
    func loadTokens() {
        isLoading = true
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let url = Bundle.main.url(forResource: "TokenDatabase", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let tokens = try? JSONDecoder().decode([TokenDefinition].self, from: data) else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    print("Failed to load token database")
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.allTokens = tokens
                self?.filteredTokens = tokens
                self?.isLoading = false
                print("Loaded \(tokens.count) tokens")
            }
        }
    }
    
    // MARK: - Search & Filter
    
    func search(query: String) {
        searchQuery = query
        
        if query.isEmpty {
            filteredTokens = allTokens
        } else {
            filteredTokens = allTokens.filter { $0.matches(query: query) }
        }
    }
    
    func filterByCategory(_ category: TokenCategory) {
        filteredTokens = allTokens.filter { token in
            TokenCategory.from(type: token.type) == category
        }
    }
    
    func filterByColors(_ colors: String) {
        if colors.isEmpty {
            // Show colorless tokens
            filteredTokens = allTokens.filter { $0.colors.isEmpty }
        } else {
            // Show tokens that contain any of the specified colors
            let colorSet = Set(colors)
            filteredTokens = allTokens.filter { token in
                !Set(token.colors).isDisjoint(with: colorSet)
            }
        }
    }
    
    // MARK: - Recent & Favorites
    
    func addToRecent(_ token: TokenDefinition) {
        var recent = recentTokens
        
        // Remove if already exists
        recent.removeAll { $0 == token.id }
        
        // Add to front
        recent.insert(token.id, at: 0)
        
        // Limit size
        if recent.count > maxRecentTokens {
            recent = Array(recent.prefix(maxRecentTokens))
        }
        
        recentTokens = recent
        saveUserPreferences()
    }
    
    func toggleFavorite(_ token: TokenDefinition) {
        if favoriteTokens.contains(token.id) {
            favoriteTokens.remove(token.id)
        } else {
            favoriteTokens.insert(token.id)
        }
        saveUserPreferences()
    }
    
    func isFavorite(_ token: TokenDefinition) -> Bool {
        favoriteTokens.contains(token.id)
    }
    
    func getRecentTokens() -> [TokenDefinition] {
        recentTokens.compactMap { id in
            allTokens.first { $0.id == id }
        }
    }
    
    func getFavoriteTokens() -> [TokenDefinition] {
        allTokens.filter { favoriteTokens.contains($0.id) }
    }
    
    // MARK: - Persistence
    
    private func loadUserPreferences() {
        if let recentData = UserDefaults.standard.array(forKey: recentTokensKey) as? [String] {
            recentTokens = recentData
        }
        
        if let favoriteData = UserDefaults.standard.array(forKey: favoriteTokensKey) as? [String] {
            favoriteTokens = Set(favoriteData)
        }
    }
    
    private func saveUserPreferences() {
        UserDefaults.standard.set(recentTokens, forKey: recentTokensKey)
        UserDefaults.standard.set(Array(favoriteTokens), forKey: favoriteTokensKey)
    }
}
```

## 2. Token Search View (`TokenSearchView.swift`)

```swift
//
//  TokenSearchView.swift
//  Doubling Season
//
//  Search interface for token database
//

import SwiftUI
import SwiftData

struct TokenSearchView: View {
    @StateObject private var database = TokenDatabase()
    @State private var searchText = ""
    @State private var selectedToken: TokenDefinition?
    @State private var showQuantityAlert = false
    @State private var tempAmount = ""
    @State private var selectedTab = 0
    @State private var selectedCategory: TokenCategory? = nil
    @State private var selectedColors = ""
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var showManualEntry: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("All").tag(0)
                    Text("Recent").tag(1)
                    Text("Favorites").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Filter chips
                if selectedTab == 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            // Category filters
                            ForEach(TokenCategory.allCases, id: \.self) { category in
                                FilterChip(
                                    title: category.rawValue,
                                    icon: category.icon,
                                    isSelected: selectedCategory == category
                                ) {
                                    if selectedCategory == category {
                                        selectedCategory = nil
                                        database.filteredTokens = database.allTokens
                                    } else {
                                        selectedCategory = category
                                        database.filterByCategory(category)
                                    }
                                }
                            }
                            
                            Divider()
                                .frame(height: 20)
                            
                            // Color filters
                            ForEach(["W", "U", "B", "R", "G", "C"], id: \.self) { color in
                                ColorFilterChip(
                                    color: color,
                                    isSelected: selectedColors.contains(color)
                                ) {
                                    if selectedColors.contains(color) {
                                        selectedColors.removeAll { String($0) == color }
                                    } else {
                                        selectedColors.append(color)
                                    }
                                    database.filterByColors(selectedColors)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 44)
                }
                
                // Token list
                if database.isLoading {
                    Spacer()
                    ProgressView("Loading tokens...")
                    Spacer()
                } else {
                    List {
                        // Show appropriate list based on tab
                        let tokensToShow: [TokenDefinition] = {
                            switch selectedTab {
                            case 1: return database.getRecentTokens()
                            case 2: return database.getFavoriteTokens()
                            default: return database.filteredTokens
                            }
                        }()
                        
                        if tokensToShow.isEmpty {
                            ContentUnavailableView(
                                "No Tokens Found",
                                systemImage: "magnifyingglass",
                                description: Text(emptyMessage)
                            )
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(tokensToShow) { token in
                                TokenSearchRow(
                                    token: token,
                                    isFavorite: database.isFavorite(token),
                                    onFavoriteToggle: {
                                        database.toggleFavorite(token)
                                    }
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedToken = token
                                    showQuantityAlert = true
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .searchable(text: $searchText, prompt: "Search tokens...")
                    .onChange(of: searchText) { _, newValue in
                        database.search(query: newValue)
                    }
                }
                
                // Bottom action bar
                Divider()
                
                Button(action: {
                    dismiss()
                    showManualEntry = true
                }) {
                    Label("Create Custom Token", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.1))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Add Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Add \(selectedToken?.name ?? "")", isPresented: $showQuantityAlert) {
                TextField("Amount", text: $tempAmount)
                    .keyboardType(.numberPad)
                
                Button("Create") {
                    if let token = selectedToken {
                        createTokenFromDatabase(token, tapped: false)
                    }
                }
                
                Button("Create Tapped") {
                    if let token = selectedToken {
                        createTokenFromDatabase(token, tapped: true)
                    }
                }
                
                Button("Cancel", role: .cancel) {
                    tempAmount = ""
                }
            } message: {
                if let token = selectedToken {
                    Text("\(token.pt) \(token.colors.isEmpty ? "Colorless" : token.colors) \(token.type)")
                }
            }
        }
    }
    
    private var emptyMessage: String {
        switch selectedTab {
        case 1: return "No recent tokens. Tokens you use will appear here."
        case 2: return "No favorite tokens. Tap the star to add favorites."
        default: return "Try adjusting your search or filters."
        }
    }
    
    private func createTokenFromDatabase(_ token: TokenDefinition, tapped: Bool) {
        let amount = Int(tempAmount) ?? 1
        let newItem = token.toItem(amount: amount, createTapped: tapped)
        
        withAnimation {
            modelContext.insert(newItem)
        }
        
        // Add to recent
        database.addToRecent(token)
        
        // Reset and dismiss
        tempAmount = ""
        dismiss()
    }
}

// MARK: - Supporting Views

struct TokenSearchRow: View {
    let token: TokenDefinition
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    
    var body: some View {
        HStack {
            // Color indicator
            VStack(spacing: 2) {
                if token.colors.isEmpty {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                } else {
                    ForEach(Array(token.colors), id: \.self) { color in
                        Circle()
                            .fill(colorForMana(color))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .frame(width: 12)
            
            // Token info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(token.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    if !token.pt.isEmpty {
                        Text(token.pt)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                if !token.abilities.isEmpty {
                    Text(token.abilities)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(token.type)
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }
            
            // Favorite button
            Button(action: onFavoriteToggle) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundColor(isFavorite ? .yellow : .gray)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
    }
    
    func colorForMana(_ mana: Character) -> Color {
        switch mana {
        case "W": return .yellow
        case "U": return .blue
        case "B": return .purple
        case "R": return .red
        case "G": return .green
        default: return .gray
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ColorFilterChip: View {
    let color: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(colorForMana(Character(color)))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.primary, lineWidth: isSelected ? 2 : 0)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    func colorForMana(_ mana: Character) -> Color {
        switch mana {
        case "W": return .yellow
        case "U": return .blue
        case "B": return .purple
        case "R": return .red
        case "G": return .green
        case "C": return .gray
        default: return .gray
        }
    }
}
```

## 3. ContentView Integration

```swift
// Modifications to ContentView.swift

struct ContentView: View {
    // ... existing properties ...
    @State private var isShowingNewTokenAlert = false  // Keep existing
    @State private var isShowingTokenSearch = false    // Already exists
    
    var body: some View {
        NavigationStack {
            // ... existing list ...
            .toolbar {
                // ... other toolbar items ...
                
                // Keep manual add button
                ToolbarItem {
                    Button(action: { isShowingNewTokenAlert = true }) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
                
                // Modify search button to show TokenSearchView
                ToolbarItem {
                    Button(action: { isShowingTokenSearch = true }) {
                        Label("Search", systemImage: "plus.magnifyingglass")
                    }
                }
            }
            // Keep existing manual entry alert
            .alert("New Token", isPresented: $isShowingNewTokenAlert) {
                // ... existing manual entry implementation ...
            }
            // Add sheet for token search
            .sheet(isPresented: $isShowingTokenSearch) {
                TokenSearchView(showManualEntry: $isShowingNewTokenAlert)
                    .presentationDetents([.large])
            }
        }
    }
}
```

## 4. Sample TokenDatabase.json

```json
[
  {
    "name": "Soldier",
    "abilities": "Vigilance",
    "pt": "1/1",
    "colors": "W",
    "type": "Token Creature — Soldier"
  },
  {
    "name": "Knight",
    "abilities": "First strike",
    "pt": "2/2",
    "colors": "W",
    "type": "Token Creature — Knight"
  },
  {
    "name": "Angel",
    "abilities": "Flying, vigilance",
    "pt": "4/4",
    "colors": "W",
    "type": "Token Creature — Angel"
  },
  {
    "name": "Drake",
    "abilities": "Flying",
    "pt": "2/2",
    "colors": "U",
    "type": "Token Creature — Drake"
  },
  {
    "name": "Zombie",
    "abilities": "",
    "pt": "2/2",
    "colors": "B",
    "type": "Token Creature — Zombie"
  },
  {
    "name": "Goblin",
    "abilities": "Haste",
    "pt": "1/1",
    "colors": "R",
    "type": "Token Creature — Goblin"
  },
  {
    "name": "Saproling",
    "abilities": "",
    "pt": "1/1",
    "colors": "G",
    "type": "Token Creature — Saproling"
  },
  {
    "name": "Beast",
    "abilities": "",
    "pt": "3/3",
    "colors": "G",
    "type": "Token Creature — Beast"
  },
  {
    "name": "Treasure",
    "abilities": "{T}, Sacrifice this artifact: Add one mana of any color.",
    "pt": "",
    "colors": "",
    "type": "Token Artifact — Treasure"
  },
  {
    "name": "Food",
    "abilities": "{2}, {T}, Sacrifice this artifact: You gain 3 life.",
    "pt": "",
    "colors": "",
    "type": "Token Artifact — Food"
  },
  {
    "name": "Clue",
    "abilities": "{2}, Sacrifice this artifact: Draw a card.",
    "pt": "",
    "colors": "",
    "type": "Token Artifact — Clue"
  },
  {
    "name": "Scute Swarm",
    "abilities": "Landfall — Whenever a land enters the battlefield under your control, create a 1/1 green Insect creature token.",
    "pt": "1/1",
    "colors": "G",
    "type": "Token Creature — Insect"
  }
]
```

## 5. Xcode Project Setup

### Add Files to Project
1. Create a new group called "TokenSearch" in your project
2. Add these new files:
   - `TokenDefinition.swift`
   - `TokenSearchView.swift`
   - `TokenDatabase.json` (add to project bundle)

### Update Info.plist (if needed)
No special permissions required since we're using bundled data.

### Build Settings
Ensure `TokenDatabase.json` is included in "Copy Bundle Resources" build phase.

## Testing Checklist

- [ ] Token database loads correctly
- [ ] Search functionality works
- [ ] Filter by category works
- [ ] Filter by color works
- [ ] Recent tokens are tracked
- [ ] Favorites can be added/removed
- [ ] Token selection creates correct Item
- [ ] Manual entry still works
- [ ] Both entry methods coexist peacefully
- [ ] UI is responsive and smooth