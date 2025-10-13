//
//  Doubling_SeasonApp.swift
//  Doubling Season
//
//  Created by DBenson on 6/4/24.
//

import SwiftUI
import SwiftData

@main
struct Doubling_SeasonApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Deck.self  // Added Deck to schema
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
