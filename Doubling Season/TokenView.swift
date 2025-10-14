//
//  Token.swift
//  Doubling Season
//
//  Created by DBenson on 6/12/24.
//

import SwiftUI

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
    
    var body: some View {
        
        // Main content WITHOUT the color bar in HStack
        HStack {
            // Empty space where color bar will overlay (not for emblems)
            if !item.isEmblem {
                Color.clear
                    .frame(width: 10)
            }
            
            VStack {
                // Top Row - Name, Color, Tapped/Untapped (not for emblems)
                HStack {
                    Text(item.name).font(.title2)
                        .frame(maxWidth: .infinity, alignment: item.isEmblem ? .center : .leading)

                    if !item.isEmblem {
                        Spacer()
                        Text(Image(systemName:"rectangle.portrait.bottomhalf.inset.filled"))
                        Text(String(item.amount - item.tapped)).font(.title2)
                        Text(Image(systemName:"rectangle.landscape.rotate"))
                        Text(String(item.tapped)).font(.title2)
                    }
                }
                
                // Counter pills (all counters except +1/+1 and -1/-1)
                if !item.counters.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 4) {
                        ForEach(item.counters, id: \.name) { counter in
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
                            item.amount += multiplier
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
                        Text(item.formattedPowerToughness).font(.title2)
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
                item.amount += (n ?? 0) * multiplier
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
                item.amount -= n ?? 0
                tempAlertValue = ""
            }
            Button("Reset", role: .destructive){
                item.amount = 0
                item.tapped = 0
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
}


#Preview {
    TokenView(item: Item(abilities:"This is a block of text representing a lot of abilities", name: "Scute Swarm", pt: "1/1", colors:"WUBRG", amount: 1, createTapped: false))
}
