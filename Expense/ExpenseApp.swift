//
//  ExpenseApp.swift
//  Expense
//
//  Created by Harshit Agarwal on 06/07/24.
//

import SwiftUI
import SwiftData
import TipKit

enum RegularAppTab: Hashable {
    case home
    case entries
    case analytics
    case budget
    case about
}

final class AppCommandCenter: ObservableObject {
    @Published var requestedTab: RegularAppTab = .home

    @Published var addExpenseCommandTick = 0
    @Published var importCSVCommandTick = 0
    @Published var focusSearchCommandTick = 0
    @Published var editSelectedCommandTick = 0
    @Published var deleteSelectedCommandTick = 0

    @Published var selectedEntryID: UUID?

    func goToTab(_ tab: RegularAppTab) {
        requestedTab = tab
    }

    func triggerAddExpense() {
        addExpenseCommandTick += 1
    }

    func triggerImportCSV() {
        importCSVCommandTick += 1
    }

    func triggerFocusSearch() {
        focusSearchCommandTick += 1
    }

    func triggerEditSelected() {
        editSelectedCommandTick += 1
    }

    func triggerDeleteSelected() {
        deleteSelectedCommandTick += 1
    }
}

struct AnalyticsFilterOptions: Equatable {
    var category: ExpenseCategory?
    var paymentMethod: PaymentMethod?
}

private struct AnalyticsFilterOptionsKey: EnvironmentKey {
    static let defaultValue = AnalyticsFilterOptions(category: nil, paymentMethod: nil)
}

extension EnvironmentValues {
    var analyticsFilterOptions: AnalyticsFilterOptions {
        get { self[AnalyticsFilterOptionsKey.self] }
        set { self[AnalyticsFilterOptionsKey.self] = newValue }
    }
}

@main
struct ExpenseApp: App {
    @StateObject private var commandCenter = AppCommandCenter()

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
                .environmentObject(commandCenter)
        }
        .modelContainer(sharedModelContainer)

        WindowGroup(id: "comparison-window") {
            NavigationStack {
                ComparisonView()
                    .navigationTitle("Compare")
            }
            .environmentObject(commandCenter)
        }
        .modelContainer(sharedModelContainer)

        WindowGroup(id: "entry-detail", for: UUID.self) { entryID in
            NavigationStack {
                EntryDetailSceneView(entryID: entryID.wrappedValue)
            }
            .environmentObject(commandCenter)
        }
        .modelContainer(sharedModelContainer)

        .commands {
            ExpenseCommandMenu(commandCenter: commandCenter)
        }
    }
}

struct EntryDetailSceneView: View {
    let entryID: UUID?
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]

    var body: some View {
        if let entryID,
           let item = items.first(where: { $0.id == entryID }) {
            ItemInfo(item: item)
                .navigationTitle("Expense Detail")
        } else {
            ContentUnavailableView(
                "No Entry Selected",
                systemImage: "doc.text",
                description: Text("Choose an expense from Entries and open it in a new window.")
            )
        }
    }
}

struct ExpenseCommandMenu: Commands {
    @ObservedObject var commandCenter: AppCommandCenter
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Expense") {
            Button("Add Expense") {
                commandCenter.goToTab(.entries)
                commandCenter.triggerAddExpense()
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("Import CSV") {
                commandCenter.goToTab(.entries)
                commandCenter.triggerImportCSV()
            }
            .keyboardShortcut("i", modifiers: [.command])

            Button("Search Entries") {
                commandCenter.goToTab(.entries)
                commandCenter.triggerFocusSearch()
            }
            .keyboardShortcut("f", modifiers: [.command])

            Divider()

            Button("Edit Selected Entry") {
                commandCenter.triggerEditSelected()
            }
            .keyboardShortcut("e", modifiers: [.command])
            .disabled(commandCenter.selectedEntryID == nil || commandCenter.requestedTab != .entries)

            Button("Delete Selected Entry") {
                commandCenter.triggerDeleteSelected()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(commandCenter.selectedEntryID == nil || commandCenter.requestedTab != .entries)

            Divider()

            Button("Open Selected Entry in New Window") {
                guard let selectedID = commandCenter.selectedEntryID else { return }
                openWindow(id: "entry-detail", value: selectedID)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(commandCenter.selectedEntryID == nil || commandCenter.requestedTab != .entries)

            Button("Open Comparison Window") {
                commandCenter.goToTab(.analytics)
                openWindow(id: "comparison-window")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        }
    }
}
