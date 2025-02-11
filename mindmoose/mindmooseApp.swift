//
//  mindmooseApp.swift
//  mindmoose
//
//  Created by Raj Jagirdar on 2/10/25.
//

import SwiftUI

@main
struct mindmooseApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
