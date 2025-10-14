//
//  ExpandedTokenView.swift
//  Doubling Season
//
//  Created on 10/13/25.
//

import SwiftUI
import SwiftData

/// Expanded token view sheet for detailed token management
/// Note: This design may be changed in the future to a different presentation style
struct ExpandedTokenView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item
    @StateObject private var counterDatabase = CounterDatabase()
    
    @State private var isEditingToken = false
    @State private var isShowingCounterSearch = false
    @State private var isShowingSplitView = false
    @State private var editableName: String = ""
    @State private var editableColors: String = ""
    @State private var editablePT: String = ""
    @State private var editableAbilities: String = ""
    
    // For multiplier support
    @AppStorage("tokenMultiplier") private var multiplier: Int = 1
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header section with name and basic info
                    headerSection
                    
                    // Counter pills section
                    if !item.counters.isEmpty || item.plusOneCounters > 0 || item.minusOneCounters > 0 {
                        counterPillsSection
                    }
                    
                    // Abilities section
                    abilitiesSection
                    
                    // Power/Toughness section (not for emblems)
                    if !item.isEmblem && !item.pt.isEmpty {
                        powerToughnessSection
                    }
                    
                    // Counters management section
                    countersSection
                    
                    // Action buttons section
                    actionButtonsSection
                    
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
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditingToken ? "Save" : "Edit") {
                        if isEditingToken {
                            saveTokenEdits()
                        } else {
                            startEditing()
                        }
                        isEditingToken.toggle()
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCounterSearch) {
            CounterSearchView(item: item)
        }
        .sheet(isPresented: $isShowingSplitView) {
            SplitStackView(item: item)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack{
                if isEditingToken {
                    TextField("Token Name", text: $editableName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.title2)
                } else {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                if !item.isEmblem {
                    // Tapped/Untapped indicators (not for emblems)
                    HStack {
                        Text(Image(systemName:"rectangle.portrait.bottomhalf.inset.filled"))
                        Text(String(item.amount - item.tapped)).font(.title2)
                        Text(Image(systemName:"rectangle.landscape.rotate"))
                        Text(String(item.tapped)).font(.title2)
                    }
                }
            }
            HStack {
                if isEditingToken {
                    TextField("Colors", text: $editableColors)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                } else if !item.isEmblem {
                    // Color indicator for non-emblems
                    HStack(spacing: 0) {
                        if item.colors.contains("W") { Color.yellow.frame(width: 8, height: 20) }
                        if item.colors.contains("U") { Color.blue.frame(width: 8, height: 20) }
                        if item.colors.contains("B") { Color.purple.frame(width: 8, height: 20) }
                        if item.colors.contains("R") { Color.red.frame(width: 8, height: 20) }
                        if item.colors.contains("G") { Color.green.frame(width: 8, height: 20) }
                        if item.colors.isEmpty || (!item.colors.contains("W") && !item.colors.contains("U") && !item.colors.contains("B") && !item.colors.contains("R") && !item.colors.contains("G")) {
                            Color.gray.frame(width: 8, height: 20)
                        }
                    }
                    .cornerRadius(4)
                }
                
                

            }
        }
    }
    
    // MARK: - Counter Pills Section
    
    private var counterPillsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Counters")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                // Regular counters (excluding +1/+1 and -1/-1)
                ForEach(item.counters, id: \.name) { counter in
                    CounterPillView(name: counter.name, amount: counter.amount)
                }
            }
        }
    }
    
    // MARK: - Abilities Section
    
    private var abilitiesSection: some View {
        VStack(alignment: item.isEmblem ? .center : .leading, spacing: 8) {
            Text("Abilities")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: item.isEmblem ? .center : .leading)
            
            if isEditingToken {
                TextEditor(text: $editableAbilities)
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            } else {
                Text(item.abilities)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: item.isEmblem ? .center : .leading)
            }
        }
    }
    
    // MARK: - Power/Toughness Section
    
    private var powerToughnessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Power/Toughness")
                .font(.headline)
            
            HStack {
                if isEditingToken {
                    TextField("P/T", text: $editablePT)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                } else {
                    Text(item.formattedPowerToughness)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // +1/+1 counter stepper
                HStack {
                    Text("+1/+1:")
                    Stepper(
                        value: Binding(
                            get: { item.netPlusOneCounters },
                            set: { newValue in
                                let difference = newValue - item.netPlusOneCounters
                                item.addPowerToughnessCounters(difference)
                            }
                        ),
                        in: -99...99
                    ) {
                        Text("\(item.netPlusOneCounters)")
                            .frame(minWidth: 30)
                    }
                }
            }
        }
    }
    
    // MARK: - Counters Section
    
    private var countersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                
                
                Button(action: {
                    isShowingCounterSearch = true
                }) {
                    Text("Add Counters")
                        .font(.headline)
                }
            }
            
            // List of all counters with increment/decrement
            if !item.counters.isEmpty {
                ForEach(item.counters, id: \.name) { counter in
                    HStack {
                        Text(counter.name)
                            .font(.body)
                        
                        Spacer()
                        
                        HStack {
                            Button(action: {
                                item.removeCounter(name: counter.name, amount: 1)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .disabled(counter.amount <= 1)
                            
                            Text("\(counter.amount)")
                                .frame(minWidth: 30)
                            
                            Button(action: {
                                item.addCounter(name: counter.name, amount: 1)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button("Remove 1") {
                    if item.amount > 0 {
                        if item.amount - item.tapped <= 0 {
                            item.tapped -= 1
                        }
                        item.amount -= 1
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Add 1") {
                    item.amount += multiplier
                }
                .buttonStyle(.borderedProminent)
            }
            
            if !item.isEmblem {
                HStack(spacing: 16) {
                    Button("Untap") {
                        if item.tapped > 0 {
                            item.tapped -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Tap") {
                        if item.tapped < item.amount {
                            item.tapped += 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Stack Management Section
    
    private var stackManagementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stack Management")
                .font(.headline)
            
            Button("Split Stack") {
                isShowingSplitView = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Helper Methods
    
    private func startEditing() {
        editableName = item.name
        editableColors = item.colors
        editablePT = item.pt
        editableAbilities = item.abilities
    }
    
    private func saveTokenEdits() {
        item.name = editableName
        item.colors = editableColors.uppercased()
        item.pt = editablePT
        item.abilities = editableAbilities
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

#Preview {
    TokenView(item: Item(abilities:"This is a block of text representing a lot of abilities", name: "Scute Swarm", pt: "1/1", colors:"WUBRG", amount: 1, createTapped: false))
}
