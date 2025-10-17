//
//  ContentView.swift
//  Doubling Season
//
//  Created by DBenson on 6/4/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.createdAt, order: .forward) private var items: [Item]
    //@Query private var utilityItems: [Item]
    @State private var isShowingNewTokenSheet = false
    @State private var activeItem: Item?
    @State private var isShowingTokenSearch = false
    @State private var isShowingUntapAlert = false
    @State private var isShowingWrathAlert = false
    @State private var isShowingSaveDeckAlert = false
    @State private var isShowingLoadDeckSheet = false
    @State private var showAbout = false
    @AppStorage("summoningSicknessEnabled") private var summoningSicknessEnabled = true
    @State private var isShowingSummoningSicknessAlert = false
    @State private var tempName = ""
    @State private var tempColors = ""
    @State private var tempAmount = ""
    @State private var tempPowerToughness = ""
    @State private var tempAbilities = ""
    @Query private var decks: [Deck]
    
    // For multiplier support
    @AppStorage("tokenMultiplier") private var multiplier: Int = 1

    var body: some View {
        ZStack {
            NavigationStack{
                List{
                    if items.isEmpty {
                        // Empty state view

                        VStack(spacing:20) {

                            Text("No tokens to display")
                                .font(.title2)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 12) {
                                Button(action: { isShowingTokenSearch = true }) {
                                    Label("Create your first token", systemImage: "plus")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                               // Label("Search for a Token", systemImage: "plus.magnifyingglass")
                                Label("Untap Everything", systemImage: "arrow.counterclockwise.circle")
                                Label("Clear Summoning Sickness", systemImage: "circle.hexagonpath")
                                Label("Save Current Deck", systemImage: "square.and.arrow.down.on.square")
                                Label("Load a Deck", systemImage: "square.and.arrow.up.on.square")
                                Label("Board Wipe", systemImage: "eraser")
                            }
                            .font(.callout)
                            .foregroundColor(.secondary)
                            Text("Long press the +/- and tap/untap buttons to mass edit a token group.")
                                .padding(15)
                                .italic(true)
                                .foregroundColor(.secondary)

                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
                        .padding(.vertical, 15)
                    } else {
                        ForEach(items){item in
                            TokenView(item: item)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                .listRowBackground(Color.clear)
                                .deleteDisabled(true)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                withAnimation {
                                                    modelContext.delete(item)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                        }
                    }
                }
                .listRowSpacing(8.0)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .toolbar {
                        ToolbarItemGroup(placement: .principal) {
                            HStack(spacing: 20) {

                                Button(action: { isShowingTokenSearch = true }) {
                                    Image(systemName: "plus")
                                }
                                
                                Button(action: { isShowingUntapAlert = true }) {
                                    Image(systemName: "arrow.counterclockwise.circle")
                                }
                                
                                Button(action: { clearSummoningSickness() }) {
                                    Image(systemName: "circle.hexagonpath")
                                }
                                .simultaneousGesture(
                                    LongPressGesture().onEnded { _ in
                                        isShowingSummoningSicknessAlert = true
                                    }
                                )
                                
                                Button(action: { isShowingSaveDeckAlert = true }) {
                                    Image(systemName: "square.and.arrow.down.on.square")
                                }

                                Button(action: { isShowingLoadDeckSheet = true }) {
                                    Image(systemName: "square.and.arrow.up.on.square")
                                }
                                
                                Button(action: { isShowingWrathAlert = true }) {
                                    Image(systemName: "eraser")
                                }
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showAbout.toggle() }) {
                                Image(systemName: "questionmark.circle")
                            }
                        }
                    }    .sheet(isPresented: $isShowingLoadDeckSheet) {
                    LoadDeckSheet()
                }
                .alert("Save Deck?", isPresented: $isShowingSaveDeckAlert){
                    TextField("Name", text: $tempName)
                    Button("Save"){
                        if !tempName.isEmpty{
                            let name = tempName
                            saveDeck(name:name)
                            resetTemp()
                        }
                    }
                    Button("Cancel",role:.cancel, action:{})
                }
                .alert("Untap Everything?", isPresented: $isShowingUntapAlert){
                                Button("Untap"){
                                    untapEverything()
                                }
                                Button("Cancel",role:.cancel, action:{})
                            }
                            .alert("Are you sure?", isPresented: $isShowingWrathAlert){
                                Button("Set tokens to zero"){
                                    wrathOfGod()
                                }
                                Button("Remove all tokens"){
                                    farewell()
                                }
                                Button("Cancel",role:.cancel, action:{})
                            }
                .alert("Summoning Sickness", isPresented: $isShowingSummoningSicknessAlert) {
                    Button("Enable") {
                        summoningSicknessEnabled = true
                    }
                    Button("Disable") {
                        summoningSicknessEnabled = false
                        clearSummoningSickness()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("When disabled, summoning sickness will not be displayed in the UI. Current summoning sickness will be cleared.")
                }
                .sheet(isPresented: $isShowingNewTokenSheet) {
                    NewTokenSheet()
                }
                .sheet(isPresented: $isShowingTokenSearch) {
                    TokenSearchView(showManualEntry: $isShowingNewTokenSheet)
                }
                .fullScreenCover(isPresented: $showAbout, content: AboutView.init)
                

            }.onAppear{
                //This is an incredibly inelegant solution to the view timer
                //problem that I don't want to have to worry about. This app
                //doesn't go to sleep. If you waste your battery that's
                //your fault not mine.
                disableViewTimer()
            }
            
            // MultiplierView positioned at the bottom
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MultiplierView()
                    Spacer()
                }
                .padding(.bottom)
            }
        }
    }
    
    // No more timing out my phone please.
    private func disableViewTimer(){
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    private func clearSummoningSickness() {
        items.forEach { item in
            item.summoningSick = 0
        }
    }
    
    private func untapEverything(){
        items.forEach { Item in
            Item.tapped = 0;
        }
    }
    
    private func wrathOfGod(){
        items.forEach { Item in
            Item.tapped = 0;
            Item.amount = 0;
            Item.summoningSick = 0;
        }
    }
    
    private func farewell(){
        for index in items{
            modelContext.delete(index)
        }
    }
    
    private func saveDeck(name: String) {
        // Create templates from current items (not Item instances)
        let templates = items.map { TokenTemplate(from: $0) }
        
        // Create and save the deck with templates
        let newDeck = Deck(name: name, templates: templates)
        modelContext.insert(newDeck)
        
        // Save context
        do {
            try modelContext.save()
        } catch {
            print("Failed to save deck: \(error)")
        }
    }
    
    
    private func loadDeck(deck: Deck) {
        // Clear current items
        items.forEach { item in
            modelContext.delete(item)
        }
        
        // Create new items from the deck
        deck.templates.forEach { deckItem in
            let newItem = Item(
                abilities: deckItem.abilities,
                name: deckItem.name,
                pt: deckItem.pt,
                colors: deckItem.colors,
                amount: 1,  // Start with 1 of each token
                createTapped: false
            )
            modelContext.insert(newItem)
        }
        
        // Save context
        do {
            try modelContext.save()
        } catch {
            print("Failed to load deck: \(error)")
        }
    }
    



    private func addItem(abilities: String, name: String, pt: String, colors: String, amount: Int, createTapped: Bool) {
        let finalAmount = amount * multiplier
        let newItem = Item(
            abilities: abilities,
            name: name,
            pt: pt,
            colors: colors,
            amount: finalAmount,
            createTapped: createTapped,
            applySummoningSickness: summoningSicknessEnabled
        )
        withAnimation {
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
    
    private func resetTemp() {
        tempName = ""
        tempColors = ""
        tempAmount = ""
        tempPowerToughness = ""
        tempAbilities = ""
    }

}



#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Deck.self, TokenCounter.self], inMemory: true )
}

