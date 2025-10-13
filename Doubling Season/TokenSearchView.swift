//
//  TokenSearchView.swift
//  Doubling Season
//
//  Created on 10/10/25.
//

import SwiftUI
import SwiftData

struct TokenSearchView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Bindings
    @Binding var showManualEntry: Bool
    
    // MARK: - State
    @StateObject private var tokenDatabase = TokenDatabase()
    @State private var searchText = ""
    @State private var selectedTab = SearchTab.all
    @State private var selectedCategory: TokenDefinition.Category? = nil
    @State private var showingQuantityDialog = false
    @State private var selectedToken: TokenDefinition? = nil
    @State private var tokenQuantity = 1
    @State private var createTapped = false
    
    // MARK: - Enums
    enum SearchTab: String, CaseIterable {
        case all = "All"
        case recent = "Recent"
        case favorites = "Favorites"
        
        var systemImage: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .recent: return "clock"
            case .favorites: return "star.fill"
            }
        }
    }
    
    // MARK: - Computed Properties
    private var displayedTokens: [TokenDefinition] {
        switch selectedTab {
        case .all:
            return tokenDatabase.filteredTokens
        case .recent:
            return tokenDatabase.recentTokens.filter { token in
                searchText.isEmpty || token.matches(searchQuery: searchText)
            }
        case .favorites:
            return tokenDatabase.getFavoriteTokens().filter { token in
                searchText.isEmpty || token.matches(searchQuery: searchText)
            }
        }
    }
    
    private var isLoading: Bool {
        tokenDatabase.isLoading
    }
    
    private var hasError: Bool {
        tokenDatabase.loadError != nil
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Tab Selector
                tabSelector
                
                // Category Filter (only shown in "All" tab)
                if selectedTab == .all {
                    categoryFilter
                }
                
                // Main Content
                if isLoading {
                    loadingView
                } else if hasError {
                    errorView
                } else if displayedTokens.isEmpty {
                    emptyStateView
                } else {
                    tokenList
                }
                
                // Create Custom Token Button
                customTokenButton
            }
            .navigationTitle("Select Token")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if selectedCategory != nil || !searchText.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") {
                            clearFilters()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingQuantityDialog) {
            quantityDialogView
        }
        .onAppear {
            // Sync search text with database
            tokenDatabase.searchQuery = searchText
        }
    }
    
    // MARK: - View Components
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search tokens...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: searchText) { newValue in
                    tokenDatabase.searchQuery = newValue
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    tokenDatabase.searchQuery = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var tabSelector: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(SearchTab.allCases, id: \.self) { tab in
                Label(tab.rawValue, systemImage: tab.systemImage)
                    .tag(tab)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TokenDefinition.Category.allCases, id: \.self) { category in
                    Button(action: {
                        if selectedCategory == category {
                            selectedCategory = nil
                            tokenDatabase.selectedCategory = nil
                        } else {
                            selectedCategory = category
                            tokenDatabase.selectedCategory = category
                        }
                    }) {
                        Text(category.displayName)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var tokenList: some View {
        List {
            ForEach(displayedTokens) { token in
                TokenSearchRow(
                    token: token,
                    isFavorite: tokenDatabase.isFavorite(token),
                    onTap: {
                        selectToken(token)
                    },
                    onToggleFavorite: {
                        tokenDatabase.toggleFavorite(token)
                    }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading tokens...")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Failed to Load Tokens")
                .font(.headline)
            
            if let error = tokenDatabase.loadError {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Retry") {
                Task {
                    await tokenDatabase.loadTokens()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: selectedTab == .favorites ? "star.slash" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(emptyStateMessage)
                .font(.headline)
                .foregroundColor(.secondary)
            
            if selectedTab == .all && (selectedCategory != nil || !searchText.isEmpty) {
                Button("Clear Filters") {
                    clearFilters()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedTab {
        case .all:
            if !searchText.isEmpty {
                return "No tokens match '\(searchText)'"
            } else if selectedCategory != nil {
                return "No \(selectedCategory!.displayName) tokens found"
            } else {
                return "No tokens available"
            }
        case .recent:
            return searchText.isEmpty ? "No recent tokens" : "No recent tokens match '\(searchText)'"
        case .favorites:
            return searchText.isEmpty ? "No favorite tokens" : "No favorites match '\(searchText)'"
        }
    }
    
    private var customTokenButton: some View {
        VStack {
            Divider()
            
            Button(action: {
                // Dismiss this view and show manual token creation
                dismiss()
                // Small delay to ensure smooth transition between sheets
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showManualEntry = true
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Custom Token")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private var quantityDialogView: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let token = selectedToken {
                    // Token Preview
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(token.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            if !token.pt.isEmpty {
                                Text(token.pt)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        
                        Text(token.cleanType)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !token.abilities.isEmpty {
                            Text(token.abilities)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Quantity Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How many tokens?")
                            .font(.headline)
                        
                        HStack {
                            Button(action: {
                                if tokenQuantity > 1 {
                                    tokenQuantity -= 1
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(tokenQuantity > 1 ? .blue : .gray)
                            }
                            .disabled(tokenQuantity <= 1)
                            
                            Spacer()
                            
                            Text("\(tokenQuantity)")
                                .font(.title)
                                .fontWeight(.bold)
                                .frame(minWidth: 50)
                            
                            Spacer()
                            
                            Button(action: {
                                tokenQuantity += 1
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Quick select buttons
                        HStack(spacing: 10) {
                            ForEach([1, 2, 3, 4, 5], id: \.self) { num in
                                Button(action: {
                                    tokenQuantity = num
                                }) {
                                    Text("\(num)")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(tokenQuantity == num ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(tokenQuantity == num ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Create Tapped Toggle
                    Toggle(isOn: $createTapped) {
                        VStack(alignment: .leading) {
                            Text("Create Tapped")
                                .font(.headline)
                            Text("Tokens enter the battlefield tapped")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Create Tokens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingQuantityDialog = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createTokens()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func selectToken(_ token: TokenDefinition) {
        selectedToken = token
        tokenQuantity = 1
        createTapped = false
        showingQuantityDialog = true
        
        // Add to recent tokens
        tokenDatabase.addToRecent(token)
    }
    
    private func createTokens() {
        guard let token = selectedToken else { return }
        
        // Create the Item from the selected token
        let item = token.toItem(amount: tokenQuantity, createTapped: createTapped)
        
        // Add to model context
        modelContext.insert(item)
        
        // Save the context
        do {
            try modelContext.save()
        } catch {
            print("Failed to save token: \(error)")
        }
        
        // Dismiss both the dialog and the search view
        showingQuantityDialog = false
        dismiss()
    }
    
    private func clearFilters() {
        searchText = ""
        selectedCategory = nil
        tokenDatabase.clearFilters()
    }
}

// MARK: - Preview
struct TokenSearchView_Previews: PreviewProvider {
    static var previews: some View {
        TokenSearchView(showManualEntry: .constant(false))
    }
}
