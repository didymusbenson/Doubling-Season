//
//  ExpandedTokenView.swift
//  Doubling Season
//
//  Created on 10/13/25.
//

import SwiftUI
import SwiftData

/// Expanded token view sheet for detailed token management
struct ExpandedTokenView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item
    @StateObject private var counterDatabase = CounterDatabase()
    
    @State private var isShowingCounterSearch = false
    @State private var isShowingSplitView = false
    
    // Editing states for tap-to-edit functionality
    @State private var editingField: EditableField? = nil
    @State private var tempEditValue: String = ""
    
    // Color selection states
    @State private var whiteSelected = false
    @State private var blueSelected = false
    @State private var blackSelected = false
    @State private var redSelected = false
    @State private var greenSelected = false
    
    @FocusState private var isTextFieldFocused: Bool
    
    // For multiplier support
    @AppStorage("tokenMultiplier") private var multiplier: Int = 1
    @AppStorage("summoningSicknessEnabled") private var summoningSicknessEnabled = true
    
    enum EditableField {
        case name, abilities, powerToughness, amount
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Token Details Section - Similar to NewTokenSheet
                    tokenDetailsSection
                    
                    // Token Controls Section
                    tokenControlsSection
                    
                    // Color Selection Section
                    colorSelectionSection
                    
                    // Counters management section
                    countersSection
                    
                    // Stack management section
                    stackManagementSection
                }
                .padding()
            }
            .navigationTitle("Token Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        saveAnyPendingEdits()
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        saveAnyPendingEdits()
                        isTextFieldFocused = false
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCounterSearch) {
            CounterSearchView(item: item)
        }
        .sheet(isPresented: $isShowingSplitView) {
            SplitStackView(item: item) {
                dismiss()
            }
        }
        .onAppear {
            updateColorSelection()
        }
    }
    
    // MARK: - Token Details Section (like NewTokenSheet)
    
    private var tokenDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Token Details")
                .font(.headline)
                .padding(.bottom, 4)
             
            VStack(alignment: .leading, spacing: 16) {
                // Name Field with P/T Badge and Amount
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // Tap to edit name
                        if editingField == .name {
                            TextField("Token Name", text: $tempEditValue)
                                .font(.title2)
                                .fontWeight(.bold)
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    item.name = tempEditValue.isEmpty ? item.name : tempEditValue
                                    editingField = nil
                                }
                                .onChange(of: isTextFieldFocused) { _, isFocused in
                                    if !isFocused && editingField == .name {
                                        item.name = tempEditValue.isEmpty ? item.name : tempEditValue
                                        editingField = nil
                                    }
                                }
                        } else {
                            Text(item.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .onTapGesture {
                                    startEditing(field: .name, currentValue: item.name)
                                }
                        }
                        
                        Spacer()
                        
                        // P/T display (tap to edit)
                        if !item.pt.isEmpty && !item.isEmblem {
                            HStack {
                                if editingField == .powerToughness {
                                    TextField("P/T", text: $tempEditValue)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .frame(width: 60)
                                        .multilineTextAlignment(.center)
                                        .focused($isTextFieldFocused)
                                        .onSubmit {
                                            item.pt = tempEditValue.isEmpty ? item.pt : tempEditValue
                                            editingField = nil
                                        }
                                        .onChange(of: isTextFieldFocused) { _, isFocused in
                                            if !isFocused && editingField == .powerToughness {
                                                item.pt = tempEditValue.isEmpty ? item.pt : tempEditValue
                                                editingField = nil
                                            }
                                        }
                                } else {
                                    Text(item.pt)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .onTapGesture {
                                            startEditing(field: .powerToughness, currentValue: item.pt)
                                        }
                                }
                                
                                // Show +1/+1 counter modification
                                if item.netPlusOneCounters != 0 {
                                    let net = item.netPlusOneCounters
                                    Text(net > 0 ? "(+\(net)/+\(net))" : "(\(net)/\(net))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Amount and status indicators
                    HStack {
                        // Tap to edit amount
                        HStack {
                            Text("Amount:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if editingField == .amount {
                                TextField("Amount", text: $tempEditValue)
                                    .font(.subheadline)
                                    .frame(width: 60)
                                    .keyboardType(.numberPad)
                                    .focused($isTextFieldFocused)
                                    .onSubmit {
                                        if let newAmount = Int(tempEditValue), newAmount >= 0 {
                                            updateAmountWithSummoningSickness(newAmount: newAmount)
                                        }
                                        editingField = nil
                                    }
                                    .onChange(of: isTextFieldFocused) { _, isFocused in
                                        if !isFocused && editingField == .amount {
                                            if let newAmount = Int(tempEditValue), newAmount >= 0 {
                                                updateAmountWithSummoningSickness(newAmount: newAmount)
                                            }
                                            editingField = nil
                                        }
                                    }
                            } else {
                                Text("\(item.amount)")
                                    .font(.subheadline)
                                    .onTapGesture {
                                        startEditing(field: .amount, currentValue: String(item.amount))
                                    }
                            }
                        }
                        
                        Spacer()
                        
                        if !item.isEmblem {
                            // Status indicators (summoning sick, tapped/untapped)
                            HStack {
                                if item.summoningSick > 0 && summoningSicknessEnabled {
                                    Text(Image(systemName:"circle.hexagonpath"))
                                    Text(String(item.summoningSick)).font(.subheadline)
                                }
                                Text(Image(systemName:"rectangle.portrait.bottomhalf.inset.filled"))
                                Text(String(item.amount - item.tapped)).font(.subheadline)
                                Text(Image(systemName:"rectangle.landscape.rotate"))
                                Text(String(item.tapped)).font(.subheadline)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Type Field (if available, not editable for now)
                if !item.name.lowercased().contains("creature") {
                    Text("Creature")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Abilities Field (tap to edit)
                VStack(alignment: .leading, spacing: 4) {
                    if editingField == .abilities {
                        TextEditor(text: $tempEditValue)
                            .font(.caption)
                            .frame(minHeight: 60)
                            .focused($isTextFieldFocused)
                            .onChange(of: isTextFieldFocused) { _, isFocused in
                                if !isFocused && editingField == .abilities {
                                    item.abilities = tempEditValue
                                    editingField = nil
                                }
                            }
                    } else {
                        Text(item.abilities.isEmpty ? "Tap to add abilities..." : item.abilities)
                            .font(.caption)
                            .foregroundColor(item.abilities.isEmpty ? .secondary.opacity(0.7) : .secondary)
                            .lineLimit(3)
                            .onTapGesture {
                                startEditing(field: .abilities, currentValue: item.abilities)
                            }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Color Selection Section
    
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
                .onChange(of: whiteSelected) { _, _ in updateColorsFromSelection() }
                
                Spacer()
                
                ColorSelectionButton(
                    symbol: "U",
                    isSelected: $blueSelected,
                    color: Color.blue,
                    label: "Blue"
                )
                .onChange(of: blueSelected) { _, _ in updateColorsFromSelection() }
                
                Spacer()
                
                ColorSelectionButton(
                    symbol: "B",
                    isSelected: $blackSelected,
                    color: Color.purple,
                    label: "Black"
                )
                .onChange(of: blackSelected) { _, _ in updateColorsFromSelection() }
                
                Spacer()
                
                ColorSelectionButton(
                    symbol: "R",
                    isSelected: $redSelected,
                    color: Color.red,
                    label: "Red"
                )
                .onChange(of: redSelected) { _, _ in updateColorsFromSelection() }
                
                Spacer()
                
                ColorSelectionButton(
                    symbol: "G",
                    isSelected: $greenSelected,
                    color: Color.green,
                    label: "Green"
                )
                .onChange(of: greenSelected) { _, _ in updateColorsFromSelection() }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Token Controls Section
    
    private var tokenControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Token Controls")
                .font(.headline)
            
            HStack(spacing: 16) {
                // Remove/Add buttons (following condensed view style)
                Button(action: {
                    if item.amount > 0 {
                        if item.amount - item.tapped <= 0 {
                            item.tapped -= 1
                        }
                        if item.amount - item.summoningSick <= 0 {
                            item.summoningSick -= 1
                        }
                        item.amount -= 1
                    }
                }) {
                    Text(Image(systemName:"minus"))
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Button(action: {
                    let tokensToAdd = multiplier
                    item.amount += tokensToAdd
                    // Always track summoning sickness when adding tokens, regardless of setting
                    item.summoningSick += tokensToAdd
                }) {
                    Text(Image(systemName:"plus"))
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                
                if !item.isEmblem {
                    Spacer()
                    // Tap/Untap buttons

                    
                    Button(action: {
                        if item.tapped < item.amount {
                            item.tapped += 1
                        }
                    }) {
                        Text(Image(systemName:"arrow.clockwise.circle"))
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        if item.tapped > 0 {
                            item.tapped -= 1
                        }
                    }) {
                        Text(Image(systemName:"arrow.counterclockwise.circle"))
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
    

    
    // MARK: - Counters Management Section
    
    private var countersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Counters")
                .font(.headline)
            
            // Display counters as larger pills with steppers, plus add counter button
            let allCounters = getAllCountersForDisplay(item: item)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                // Existing counter pills
                ForEach(allCounters, id: \.name) { counter in
                    CounterManagementPillView(
                        counter: counter,
                        onDecrement: {
                            if counter.name == "+1/+1" {
                                item.addPowerToughnessCounters(-1)
                            } else if counter.name == "-1/-1" {
                                item.minusOneCounters = max(0, item.minusOneCounters - 1)
                            } else {
                                item.removeCounter(name: counter.name, amount: 1)
                            }
                        },
                        onIncrement: {
                            if counter.name == "+1/+1" {
                                item.addPowerToughnessCounters(1)
                            } else if counter.name == "-1/-1" {
                                item.minusOneCounters += 1
                            } else {
                                item.addCounter(name: counter.name, amount: 1)
                            }
                        }
                    )
                }
                
                // Add counter button styled as a pill
                Button(action: {
                    isShowingCounterSearch = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        )
                }
            }
        }
    }
    
    // MARK: - Stack Management Section
    
    private var stackManagementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stack Management")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button("Split Stack") {
                    isShowingSplitView = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("Copy Token") {
                    copyToken()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func startEditing(field: EditableField, currentValue: String) {
        editingField = field
        tempEditValue = currentValue
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = true
        }
    }
    
    private func updateAmountWithSummoningSickness(newAmount: Int) {
        let oldAmount = item.amount
        
        // Update the amount first
        item.amount = newAmount
        
        // Handle summoning sickness adjustments
        if newAmount > oldAmount {
            // Amount increased - always add summoning sick tokens for the difference (tracking regardless of setting)
            let difference = newAmount - oldAmount
            item.summoningSick += difference
        } else if newAmount < item.summoningSick {
            // Amount decreased below summoning sick count - cap summoning sick to new amount
            item.summoningSick = newAmount
        }
        
        // Also ensure tapped count doesn't exceed new amount
        if item.tapped > newAmount {
            item.tapped = newAmount
        }
    }
    
    private func saveAnyPendingEdits() {
        guard let field = editingField else { return }
        
        switch field {
        case .name:
            if !tempEditValue.isEmpty {
                item.name = tempEditValue
            }
        case .abilities:
            item.abilities = tempEditValue
        case .powerToughness:
            if !tempEditValue.isEmpty {
                item.pt = tempEditValue
            }
        case .amount:
            if let newAmount = Int(tempEditValue), newAmount >= 0 {
                updateAmountWithSummoningSickness(newAmount: newAmount)
            }
        }
        
        editingField = nil
    }
    
    private func updateColorSelection() {
        whiteSelected = item.colors.contains("W")
        blueSelected = item.colors.contains("U")
        blackSelected = item.colors.contains("B")
        redSelected = item.colors.contains("R")
        greenSelected = item.colors.contains("G")
    }
    
    private func updateColorsFromSelection() {
        var newColors = ""
        if whiteSelected { newColors += "W" }
        if blueSelected { newColors += "U" }
        if blackSelected { newColors += "B" }
        if redSelected { newColors += "R" }
        if greenSelected { newColors += "G" }
        
        item.colors = newColors
    }
    
    // MARK: - Copy Token Function
    private func copyToken() {
        // Create a new token with the same properties but amount = 1 * multiplier
        let copyAmount = 1 * multiplier
        let newItem = Item(
            abilities: item.abilities,
            name: item.name,
            pt: item.pt,
            colors: item.colors,
            amount: copyAmount,
            createTapped: false,
            applySummoningSickness: true  // Copied tokens should always have summoning sickness, regardless of setting
        )
        
        // Copy counters from the original
        newItem.plusOneCounters = item.plusOneCounters
        newItem.minusOneCounters = item.minusOneCounters
        newItem.counters = item.counters.map { TokenCounter(name: $0.name, amount: $0.amount) }
        
        withAnimation {
            modelContext.insert(newItem)
        }
    }
}

// MARK: - Counter Pill View

struct CounterPillView: View {
    let name: String
    let amount: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
            
            if amount > 1 {
                Text("\(amount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Counter Management Pill View

struct CounterManagementPillView: View {
    let counter: TokenCounter
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onDecrement) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.red)
            }
            .disabled(counter.amount <= 1)
            
            VStack(spacing: 2) {
                Text(counter.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text("\(counter.amount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity)
            
            Button(action: onIncrement) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    TokenView(item: Item(abilities:"This is a block of text representing a lot of abilities", name: "Scute Swarm", pt: "1/1", colors:"WUBRG", amount: 1, createTapped: false))
}
