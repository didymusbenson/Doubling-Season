//
//  Token.swift
//  Doubling Season
//
//  Created by DBenson on 6/12/24.
//

import SwiftUI
import SwiftData

struct TokenView: View {
    
    @State var item: Item
    @State private var isShowingRemoveAlert = false
    @State private var isShowingAddAlert = false
    @State private var isShowingUntapAlert = false
    @State private var isShowingTapAlert = false
    @State private var isShowingExpandedView = false
    @State private var tempAlertValue = ""
    
    // For multiplier support
    @AppStorage("tokenMultiplier") private var multiplier: Int = 1
    @AppStorage("summoningSicknessEnabled") private var summoningSicknessEnabled = true
    
    // Environment for copying tokens
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        
        // Main content WITHOUT the color bar in HStack
        HStack {
            // Empty space where color bar will overlay (not for emblems)
            if !item.isEmblem {
                Color.clear
                    .frame(width: 10)
            }
            
            VStack {
                // Top Row - Name, Color, Summoning Sick, Tapped/Untapped (not for emblems)
                HStack {
                    Text(item.name).font(.title2)
                        .frame(maxWidth: .infinity, alignment: item.isEmblem ? .center : .leading)

                    if !item.isEmblem {
                        Spacer()
                        // Summoning sick indicator (only show if > 0 and setting is enabled)
                        if item.summoningSick > 0 && summoningSicknessEnabled {
                            Text(Image(systemName:"circle.hexagonpath"))
                            Text(String(item.summoningSick)).font(.title2)
                        }
                        Text(Image(systemName:"rectangle.portrait.bottomhalf.inset.filled"))
                        Text(String(item.amount - item.tapped)).font(.title2)
                        Text(Image(systemName:"rectangle.landscape.rotate"))
                        Text(String(item.tapped)).font(.title2)
                    }
                }
                
                // Counter pills (all counters including +1/+1 and -1/-1)
                let allCounters = getAllCountersForDisplay(item: item)
                if !allCounters.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 4) {
                        ForEach(allCounters, id: \.name) { counter in
                            CounterPillView(name: counter.name, amount: counter.amount)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Middle row - abilities/counters
                Text(item.abilities)
                    .frame(maxWidth: .infinity, alignment: item.isEmblem ? .center : .leading)
            
                // Bottom Row - buttons, Power/Toughness (not for emblems)
                if !item.isEmblem {
                    HStack {
                        // subtract
                        Button(action:{}){
                            Text(Image(systemName:"minus")).font(.title2)
                        }.buttonStyle(BorderlessButtonStyle())
                        .simultaneousGesture(LongPressGesture().onEnded { _ in
                            isShowingRemoveAlert = true
                        })
                        .simultaneousGesture(TapGesture().onEnded {
                            if(item.amount > 0){
                                if (item.amount - item.tapped <= 0){
                                    item.tapped -= 1
                                }
                                if (item.amount - item.summoningSick <= 0){
                                    item.summoningSick -= 1
                                }
                                item.amount -= 1
                            }
                        })
                        // add
                        Button(action:{}){
                            Text(Image(systemName:"plus")).font(.title2)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .simultaneousGesture(LongPressGesture().onEnded { _ in
                            isShowingAddAlert = true
                        })
                        .simultaneousGesture(TapGesture().onEnded {
                            let tokensToAdd = multiplier
                            item.amount += tokensToAdd
                            // Always track summoning sickness when adding tokens, regardless of setting
                            item.summoningSick += tokensToAdd
                        })
                        // tap
                        Button(action:{
                            
                        }){
                            Text(Image(systemName:"arrow.clockwise.circle")).font(.title2)
                        }.buttonStyle(BorderlessButtonStyle())
                        .simultaneousGesture(LongPressGesture().onEnded { _ in
                            isShowingTapAlert = true
                        })
                        .simultaneousGesture(TapGesture().onEnded {
                            if(item.tapped < item.amount){
                                item.tapped += 1
                            }
                        })
                        
                        // untap
                        Button(action:{
                        }){
                            Text(Image(systemName:"arrow.counterclockwise.circle")).font(.title2)
                        }.buttonStyle(BorderlessButtonStyle())
                        .simultaneousGesture(LongPressGesture().onEnded { _ in
                            isShowingUntapAlert = true
                        })
                        .simultaneousGesture(TapGesture().onEnded {
                            if(item.tapped > 0){
                                item.tapped -= 1
                            }
                            
                        })
                        
                        // copy
                        Button(action:{
                            copyToken()
                        }){
                            Text(Image(systemName:"document.on.document")).font(.title2)
                        }.buttonStyle(BorderlessButtonStyle())

                        //SCUTE SWARM
                        if (item.name.uppercased() == "SCUTE SWARM"){
                            Button (action:{
                                
                            }){
                                Text(Image(systemName:"ladybug.circle")).font(.title2)
                            }.simultaneousGesture(TapGesture().onEnded {
                                item.amount *= 2
                            })
                            Spacer()
                        }
                        Spacer()
                        // Power/Toughness with styling for modifications
                        if item.isPowerToughnessModified {
                            Text(item.formattedPowerToughness)
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        } else {
                            Text(item.formattedPowerToughness).font(.title2)
                        }
                    }
                }
            }.padding([.top, .bottom, .trailing], 10).opacity(item.amount == 0 ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: item.amount == 0)
        }
        .overlay(alignment: .leading) {
            // Color bar as overlay - completely independent of layout (not for emblems)
            if !item.isEmblem {
                VStack(spacing: 0) {
                    if item.colors.contains("W") {
                        Color.yellow
                    }
                    if item.colors.contains("U") {
                        Color.blue
                    }
                    if item.colors.contains("B") {
                        Color.purple
                    }
                    if item.colors.contains("R") {
                        Color.red
                    }
                    if item.colors.contains("G") {
                        Color.green
                    }
                    if item.colors.isEmpty ||
                       (!item.colors.contains("W") &&
                        !item.colors.contains("U") &&
                        !item.colors.contains("B") &&
                        !item.colors.contains("R") &&
                        !item.colors.contains("G")) {
                        Color.gray
                    }
                }
                .frame(width: 10)
                .allowsHitTesting(false) // Important: don't block touches
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            isShowingExpandedView = true
        }
        .sheet(isPresented: $isShowingExpandedView) {
            ExpandedTokenView(item: item)
        }
        .alert("Add Tokens", isPresented: $isShowingAddAlert){
            TextField("Value", text: $tempAlertValue)
            Button("Submit"){
                let n: Int? = Int(tempAlertValue)
                let tokensToAdd = (n ?? 0) * multiplier
                item.amount += tokensToAdd
                // Always track summoning sickness when adding tokens, regardless of setting
                item.summoningSick += tokensToAdd
                tempAlertValue = ""
            }
        }message:{
            Text("How many \(item.name)? (Will be multiplied by x\(multiplier))")
        }
        .alert("Remove Tokens", isPresented: $isShowingRemoveAlert){
            TextField("Value", text: $tempAlertValue)
            Button("Remove"){
                var n: Int? = Int(tempAlertValue)
                if(n ?? 0 > item.amount){
                    n = item.amount
                }
                let tokensToRemove = n ?? 0
                item.amount -= tokensToRemove
                // Reduce summoning sick count proportionally
                if item.summoningSick > tokensToRemove {
                    item.summoningSick -= tokensToRemove
                } else {
                    item.summoningSick = 0
                }
                tempAlertValue = ""
            }
            Button("Reset", role: .destructive){
                item.amount = 0
                item.tapped = 0
                item.summoningSick = 0
            }
        }message:{
            Text("Remove tokens \(item.name)?")
        }
        .alert("Untap", isPresented: $isShowingUntapAlert){
            TextField("Value", text: $tempAlertValue)
            Button("Untap"){
                var n: Int? = Int(tempAlertValue)
                if(n ?? 0 > item.tapped){
                    n = item.tapped
                }
                item.tapped -= n ?? 0
                tempAlertValue = ""
            }
        }message:{
            Text("Untap tokens \(item.name)?")
        }
        .alert("Tap Tokens", isPresented: $isShowingTapAlert){
            TextField("Value", text: $tempAlertValue)
            Button("Tap"){
                let n: Int? = Int(tempAlertValue)
                if(n ?? 0 > item.amount - item.tapped){
                    item.tapped = item.amount
                }
                else{
                    item.tapped += n ?? 0
                }
                tempAlertValue = ""
            }
        }message:{
            Text("How many \(item.name)?")
        }
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

// Helper function to get all counters including +1/+1 and -1/-1
func getAllCountersForDisplay(item: Item) -> [TokenCounter] {
    var allCounters: [TokenCounter] = []
    
    // Add regular counters
    allCounters.append(contentsOf: item.counters)
    
    // Add +1/+1 counters if any
    if item.plusOneCounters > 0 {
        allCounters.append(TokenCounter(name: "+1/+1", amount: item.plusOneCounters))
    }
    
    // Add -1/-1 counters if any
    if item.minusOneCounters > 0 {
        allCounters.append(TokenCounter(name: "-1/-1", amount: item.minusOneCounters))
    }
    
    return allCounters
}


#Preview {
    TokenView(item: Item(abilities:"This is a block of text representing a lot of abilities", name: "Scute Swarm", pt: "1/1", colors:"WUBRG", amount: 1, createTapped: false))
}
