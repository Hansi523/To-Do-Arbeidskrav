//
//  To_Do_arbeidskravApp.swift
//  To-Do arbeidskrav
//
//  Created by Hans Inge Paulshus on 28/09/2025.
//

import SwiftUI
import SwiftData

@main
struct To_Do_arbeidskravApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
