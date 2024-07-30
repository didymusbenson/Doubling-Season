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
    @Query private var items: [Item]
    @State private var isShowingNewTokenAlert = false
    @State private var activeItem: Item?
    @State private var isShowingTokenSearch = false
    @State private var isShowingUntapAlert = false
    @State private var isShowingWrathAlert = false
    @State private var tempName = ""
    @State private var tempColors = ""
    @State private var tempAmount = ""
    @State private var tempPowerToughness = ""
    @State private var tempAbilities = ""


    var body: some View {
        
            NavigationStack{
                List{
                    ForEach(items){item in
                        TokenView(item: item).listRowSeparator(.hidden).listRowInsets(EdgeInsets())
                                                
                    }
                    .onDelete(perform: deleteItems)
                    
                    
                }.listRowSpacing(8.0)

                .toolbar {

    #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
    #endif
                    ToolbarItem(){
                        Button(action:{isShowingWrathAlert = true}){
                            Label("Wrath", systemImage:"trash.fill")
                        }
                    }
                    /*
                     TODO: Put these in another toolbar somewhere else.
                    ToolbarItem(){
                        Button(action:{saveDeck()}){
                            Label("SAVE", systemImage:"folder.badge.plus")
                        }
                    }
                    
                    ToolbarItem(){
                        Button(action:{loadDeck()}){
                            Label("SAVE", systemImage:"rectangle.portrait.on.rectangle.portrait.angled")
                        }
                    }
                    */
                    ToolbarItem(){
                        Button(action:{isShowingUntapAlert = true}){
                            Label("Untap", systemImage:"arrow.counterclockwise.circle")
                        }
                    }


                    ToolbarItem (){
                        Button(action:{isShowingNewTokenAlert = true}) {
                            Label("Add Item", systemImage: "plus")
                        }
                    }
                    ToolbarItem(){
                        Button(action:{isShowingTokenSearch = true}){
                            Label("Search", systemImage: "plus.magnifyingglass")
                        }
                    }
                    

                }
                            .alert("Untap Everything?", isPresented: $isShowingUntapAlert){
                                Button("Untap"){
                                    untapEverything()
                                }
                                Button("Cancel",role:.cancel, action:{})
                            }
                            .alert("Are you sure?", isPresented: $isShowingWrathAlert){
                                Button("Destroy all tokens"){
                                    wrathOfGod()
                                }
                                Button("Reset your board"){
                                    farewell()
                                }
                                Button("Cancel",role:.cancel, action:{})
                            }
                .alert("New Token", isPresented: $isShowingNewTokenAlert){
                    TextField("Name", text: $tempName)
                    TextField("Colors (WUBRG)", text: $tempColors)
                    TextField("How Many", text: $tempAmount)
                    TextField("Abilities", text: $tempAbilities)
                    TextField("X/X", text: $tempPowerToughness)
                    
                    Button("Create"){
                        let n: Int? = Int(tempAmount)
                        addItem(
                            abilities: tempAbilities,
                            name: tempName,
                            pt: tempPowerToughness,
                            colors: tempColors,
                            amount: n ?? 0,
                            createTapped: false
                        )
                        resetTemp()
                    }
                    Button("Create Tapped"){
                        let n: Int? = Int(tempAmount)
                        addItem(
                            abilities: tempAbilities,
                            name: tempName,
                            pt: tempPowerToughness,
                            colors: tempColors,
                            amount: n ?? 0,
                            createTapped: true
                        )
                        resetTemp()
                    }
                    Button("Cancel", role: .cancel, action:{})
                   
                }

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
        }
    }
    
    private func farewell(){
        for index in items{
            modelContext.delete(index)
        }
    }
    
    private func saveDeck(){
       
    }
    
    private func loadDeck(){
       
    }


    private func addItem(abilities: String, name: String, pt: String, colors: String, amount: Int, createTapped: Bool) {
        let newItem = Item(
            abilities: abilities,
            name: name,
            pt: pt,
            colors: colors,
            amount: amount,
            createTapped: createTapped
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
        .modelContainer(for: Item.self, inMemory: true)
}
