//
//  ContentView.swift
//  Expense
//
//  Created by Harshit Agarwal on 06/07/24.
//

import SwiftUI
import SwiftData
import Combine
import TipKit

// MARK: - Adaptive Root View (TabView on iPhone, SplitView on iPad)

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .compact {
            CompactTabView()
        } else {
            RegularSplitView()
        }
    }
}

// MARK: - iPhone: Tab-based Navigation

struct CompactTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            NavigationStack {
                EntryListView()
            }
            .tabItem {
                Label("Entries", systemImage: "list.bullet.rectangle.fill")
            }
            .tag(1)

            NavigationStack {
                DataView()
            }
            .tabItem {
                Label("Analytics", systemImage: "chart.bar.fill")
            }
            .tag(2)

            NavigationStack {
                BudgetView()
                    .navigationTitle("Budget")
            }
            .tabItem {
                Label("Budget", systemImage: "target")
            }
            .tag(3)

            NavigationStack {
                AboutUsView()
                    .navigationTitle("About")
            }
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
            .tag(4)
        }
        .tint(.blue)
    }
}

// MARK: - iPad/Mac: Split View (preserves existing behaviour)

enum AppSection: String, Identifiable, CaseIterable {
    case home, entry, data, budget, aboutUs

    var id: String { rawValue }

    var name: String {
        switch self {
        case .home: return "Home"
        case .entry: return "Entries"
        case .data: return "Analytics"
        case .budget: return "Budget"
        case .aboutUs: return "About"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .entry: return "list.bullet.rectangle.fill"
        case .data: return "chart.bar.fill"
        case .budget: return "target"
        case .aboutUs: return "info.circle"
        }
    }
}

struct RegularSplitView: View {
    @State private var selectedSection: AppSection? = .home
    @State private var isPresented = false
    @State private var selectedItem: Item?

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, id: \.self, selection: $selectedSection) { section in
                Label(section.name, systemImage: section.icon)
            }
            .listStyle(.sidebar)
            .navigationTitle("Expense")
        } detail: {
            switch selectedSection {
            case .home:
                HomeView()
                    .navigationTitle("Home")
            case .entry:
                HStack(spacing: 0) {
                    EntryListView()
                        .frame(minWidth: 300, idealWidth: 350, maxWidth: 400)
                    Divider()
                    if let item = selectedItem {
                        ItemInfo(item: item)
                            .id(item.id)
                            .frame(maxWidth: .infinity)
                    } else {
                        ContentUnavailableView("Select an Entry", systemImage: "doc.text", description: Text("Pick an expense from the list to see details."))
                            .frame(maxWidth: .infinity)
                    }
                }
                .navigationTitle("Entries")
            case .data:
                DataView()
                    .navigationTitle("Analytics")
            case .budget:
                BudgetView()
                    .navigationTitle("Budget")
            case .aboutUs:
                AboutUsView()
                    .navigationTitle("About")
            case .none:
                ContentUnavailableView("Select a Section", systemImage: "sidebar.left", description: Text("Choose a section from the sidebar."))
            }
        }
    }
}

// MARK: - Entry List (Push-detail on iPhone)

struct EntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    @Query private var DCS: [DailyCategorySummary]
    @Query private var MCS: [MonthlyCategorySummary]
    @State private var isPresented = false
    @State private var searchText = ""
    @State private var deleteTrigger = false
    private let searchTip = SearchExpensesTip()

    var filteredItems: [Item] {
        if searchText.isEmpty { return items }
        return items.filter { item in
            item.descriptions.localizedCaseInsensitiveContains(searchText) ||
            item.category.rawValue.localizedCaseInsensitiveContains(searchText) ||
            String(format: "%.2f", item.amount).contains(searchText)
        }
    }

    /// Group entries by day for section headers
    private var groupedByDay: [(date: Date, items: [Item])] {
        let grouped = Dictionary(grouping: filteredItems) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, items: $0.value) }
    }

    var body: some View {
        List {
            TipView(searchTip)

            ForEach(groupedByDay, id: \.date) { group in
                Section {
                    ForEach(group.items, id: \.id) { item in
                        NavigationLink(value: item) {
                            EntryRow(item: item)
                        }
                    }
                    .onDelete { offsets in deleteItems(from: group.items, at: offsets) }
                } header: {
                    Text(group.date.formatted(.dateTime.month(.abbreviated).day().year()))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Entries")
        .navigationDestination(for: Item.self) { item in
            ItemInfo(item: item)
        }
        .searchable(text: $searchText, prompt: "Search expenses…")
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty { SearchExpensesTip.hasSearched = true }
        }
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.5), trigger: deleteTrigger)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { deleteAllItems() } label: { Label("Delete All", systemImage: "trash") }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { isPresented = true } label: { Label("Add Expense", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $isPresented) {
            AddView(isPresented: $isPresented)
        }
    }

    // MARK: Actions

    private func addSampleItems() {
        withAnimation {
            for item in sampleItems {
                ExpenseDataManager.addItemAndUpdateSummaries(item: item, dailySummaries: DCS, monthlySummaries: MCS, context: modelContext)
            }
        }
    }

    private func deleteItems(from groupItems: [Item], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let item = groupItems[index]
                ExpenseDataManager.deleteItemAndUpdateSummaries(item: item, dailySummaries: DCS, monthlySummaries: MCS, context: modelContext)
            }
            deleteTrigger.toggle()
        }
    }

    private func deleteAllItems() {
        withAnimation {
            ExpenseDataManager.deleteAllData(items: items, dailySummaries: DCS, monthlySummaries: MCS, context: modelContext)
            deleteTrigger.toggle()
        }
    }
}

// MARK: - Entry Row (clean, informative)

struct EntryRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForCategory(item.category))
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .background(.blue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !item.descriptions.isEmpty {
                    Text(item.descriptions)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("₹\(String(format: "%.0f", item.amount))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(item.date.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconForCategory(_ category: ExpenseCategory) -> String {
        switch category {
        case .food, .breakfast, .lunch, .dinner: return "fork.knife"
        case .transport, .publicTransport, .taxi: return "bus.fill"
        case .groceries: return "cart.fill"
        case .utilities, .internet, .phone, .cable: return "bolt.fill"
        case .rent, .mortgage: return "house.fill"
        case .entertainment, .movies, .music, .theater, .concerts, .sportingEvents: return "film.fill"
        case .healthcare, .insurance: return "heart.fill"
        case .education, .books: return "book.fill"
        case .fitness: return "figure.run"
        case .clothing, .personalCare: return "tshirt.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .snacks: return "takeoutbag.and.cup.and.straw.fill"
        case .fuel, .carMaintenance, .parking: return "car.fill"
        case .flights, .vacation: return "airplane"
        case .shopping: return "bag.fill"
        case .investment, .savings: return "chart.line.uptrend.xyaxis"
        case .subscriptions: return "repeat"
        case .gifts, .charity: return "gift.fill"
        case .pets: return "pawprint.fill"
        case .alcohol: return "wineglass.fill"
        case .hobbies: return "puzzlepiece.fill"
        case .homeImprovement, .gardening, .furniture, .decorations, .householdSupplies: return "hammer.fill"
        case .childcare: return "figure.2.and.child.holdinghands"
        case .debtRepayment, .creditCard, .bankingFees: return "creditcard.fill"
        case .electronics: return "desktopcomputer"
        case .businessExpenses, .legalFees, .taxes, .fines: return "briefcase.fill"
        case .miscellaneous: return "ellipsis.circle.fill"
        }
    }
}
struct AboutUsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "indianrupeesign.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.blue)
                
                Text("Expense Tracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 2.0.0 — Redesigned for iPhone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    AboutRow(icon: "person.fill", title: "Developer", detail: "Harshit Agarwal")
                    AboutRow(icon: "swift", title: "Built With", detail: "SwiftUI & SwiftData")
                    AboutRow(icon: "chart.bar.fill", title: "Charts", detail: "Swift Charts")
                    AboutRow(icon: "lightbulb.fill", title: "TipKit", detail: "Onboarding Tips")
                    AboutRow(icon: "iphone", title: "Platform", detail: "iOS / iPadOS / macOS")
                    AboutRow(icon: "calendar", title: "Started", detail: "July 2024")
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features")
                        .font(.headline)
                    FeatureRow(icon: "house.fill", text: "Beautiful home dashboard with hero summary")
                    FeatureRow(icon: "plus.circle.fill", text: "Quick expense entry with 60+ categories")
                    FeatureRow(icon: "chart.pie.fill", text: "Ring chart category breakdown")
                    FeatureRow(icon: "chart.bar.fill", text: "Weekly, monthly, and yearly bar charts")
                    FeatureRow(icon: "arrow.left.arrow.right", text: "Side-by-side period comparison")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Spending trends with moving average")
                    FeatureRow(icon: "heart.text.square.fill", text: "Financial health score (0–100)")
                    FeatureRow(icon: "target", text: "Category budgets with coaching nudges")
                    FeatureRow(icon: "lightbulb.fill", text: "Smart insight cards & recommendations")
                    FeatureRow(icon: "magnifyingglass", text: "Search and filter expenses")
                    FeatureRow(icon: "iphone", text: "iPhone-optimized TabView navigation")
                    FeatureRow(icon: "hand.tap.fill", text: "Haptic sensory feedback")
                    FeatureRow(icon: "sparkles", text: "TipKit onboarding tips")
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
}

struct AboutRow: View {
    let icon: String
    let title: String
    let detail: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(detail)
                .foregroundStyle(.secondary)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
