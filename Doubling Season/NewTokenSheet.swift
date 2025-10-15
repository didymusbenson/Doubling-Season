//
//  NewTokenSheet.swift
//  Doubling Season
//
//  Created on 10/10/25.
//

import SwiftUI
import SwiftData

struct NewTokenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State Properties
    @State private var tokenName = ""
    @State private var tokenType = ""
    @State private var powerToughness = ""
    @State private var abilities = ""
    @State private var tokenQuantity = 1
    @State private var createTapped = false
    
    // Color selection states
    @State private var whiteSelected = false
    @State private var blueSelected = false
    @State private var blackSelected = false
    @State private var redSelected = false
    @State private var greenSelected = false
    
    @FocusState private var focusedField: Field?
    @AppStorage("summoningSicknessEnabled") private var summoningSicknessEnabled = true
    
    enum Field {
        case name, type, powerToughness, abilities
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Token Details Section - Mimics the token preview from TokenSearchView
                        tokenDetailsSection
                        
                        // Color Selection Section
                        colorSelectionSection
                        
                        // Quantity Selector - Same style as TokenSearchView
                        quantitySection
                        
                        // Create Tapped Toggle - Same style as TokenSearchView
                        createTappedSection
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Create Custom Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createToken()
                    }
                    .fontWeight(.bold)
                    .disabled(tokenName.isEmpty)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var tokenDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Token Details")
                .font(.headline)
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 16) {
                // Name Field with P/T Badge
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Token Name", text: $tokenName)
                            .font(.title2)
                            .fontWeight(tokenName.isEmpty ? .regular : .bold)
                            .focused($focusedField, equals: .name)
                        
                        if !powerToughness.isEmpty {
                            Text(powerToughness)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Type Field
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Creature Type (e.g., Creature — Soldier)", text: $tokenType)
                        .font(.subheadline)
                        .foregroundColor(tokenType.isEmpty ? .secondary : .primary)
                        .focused($focusedField, equals: .type)
                }
                
                // Abilities Field
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Abilities (e.g., Flying, Vigilance)", text: $abilities, axis: .vertical)
                        .font(.caption)
                        .foregroundColor(abilities.isEmpty ? .secondary.opacity(0.7) : .secondary)
                        .lineLimit(1...3)
                        .focused($focusedField, equals: .abilities)
                }
                
                // Power/Toughness Field
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Power/Toughness (e.g., 2/2)", text: $powerToughness)
                        .font(.caption)
                        .foregroundColor(powerToughness.isEmpty ? .secondary.opacity(0.7) : .primary)
                        .focused($focusedField, equals: .powerToughness)
                }
                

            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private var colorSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color Identity")
                .font(.headline)
            
            HStack() {
                
                ColorSelectionButton(
                    symbol: "W",
                    isSelected: $whiteSelected,
                    color: Color.yellow,
                    label: "White"
                )
                Spacer()
                ColorSelectionButton(
                    symbol: "U",
                    isSelected: $blueSelected,
                    color: Color.blue,
                    label: "Blue"
                )
                Spacer()
                ColorSelectionButton(
                    symbol: "B",
                    isSelected: $blackSelected,
                    color: Color.purple,
                    label: "Black"
                )
                Spacer()
                ColorSelectionButton(
                    symbol: "R",
                    isSelected: $redSelected,
                    color: Color.red,
                    label: "Red"
                )
                Spacer()
                ColorSelectionButton(
                    symbol: "G",
                    isSelected: $greenSelected,
                    color: Color.green,
                    label: "Green"
                )
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private var quantitySection: some View {
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
                
                TextField("Quantity", value: $tokenQuantity, format: .number)
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(minWidth: 50)
                    .multilineTextAlignment(.center)
                    .onChange(of: tokenQuantity) { _, newValue in
                        // Ensure quantity is never less than 1
                        if newValue < 1 {
                            tokenQuantity = 1
                        }
                    }
                
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
    }
    
    private var createTappedSection: some View {
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
    }
    
    // MARK: - Helper Methods
    
    private func createToken() {
        // Build the colors string from selected checkboxes
        var colorString = ""
        if whiteSelected { colorString += "W" }
        if blueSelected { colorString += "U" }
        if blackSelected { colorString += "B" }
        if redSelected { colorString += "R" }
        if greenSelected { colorString += "G" }
        
        // Create the new token item
        let newItem = Item(
            abilities: abilities,
            name: tokenName,
            pt: powerToughness,
            colors: colorString,
            amount: max(1, tokenQuantity),
            createTapped: createTapped,
            applySummoningSickness: summoningSicknessEnabled
        )
        
        // Add to model context with animation
        withAnimation {
            modelContext.insert(newItem)
        }
        
        // Save the context
        do {
            try modelContext.save()
        } catch {
            print("Failed to save token: \(error)")
        }
        
        dismiss()
    }
}

// MARK: - Supporting Views

struct ColorSelectionButton: View {
    let symbol: String
    @Binding var isSelected: Bool
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isSelected ? color : Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                
                Text(symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                if isSelected {
                    Circle()
                        .stroke(Color.blue, lineWidth: 3)
                        .frame(width: 48, height: 48)
                }
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSelected.toggle()
            }
        }
    }
}

// MARK: - Preview

struct NewTokenSheet_Previews: PreviewProvider {
    static var previews: some View {
        NewTokenSheet()
            .modelContainer(for: Item.self, inMemory: true)
    }
}
