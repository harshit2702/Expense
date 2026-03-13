//
//  ExpenseApp.swift
//  Expense
//
//  Created by Harshit Agarwal on 06/07/24.
//

import SwiftUI
import SwiftData
import TipKit

@main
struct ExpenseApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            DailyCategorySummary.self,
            MonthlyCategorySummary.self,
            Budget.self,
            MonthlyBudgetSettings.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Configure TipKit — resets tips during development if needed
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
