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
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Adaptive Root View (TabView on iPhone, SplitView on iPad)

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .compact {
            CompactTabView()
        } else {
            RegularSidebarTabContainer()
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

struct RegularSidebarTabContainer: View {
    @EnvironmentObject private var commandCenter: AppCommandCenter
    @State private var selectedTab: RegularAppTab = .home

    var body: some View {
        let tabs = TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(RegularAppTab.home)

            RegularEntriesSplitView()
                .tabItem {
                    Label("Entries", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(RegularAppTab.entries)

            RegularAnalyticsSplitView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.fill")
                }
                .tag(RegularAppTab.analytics)

            NavigationStack {
                BudgetView()
                    .navigationTitle("Budget")
            }
            .tabItem {
                Label("Budget", systemImage: "target")
            }
            .tag(RegularAppTab.budget)

            NavigationStack {
                AboutUsView()
                    .navigationTitle("About")
            }
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
            .tag(RegularAppTab.about)
        }
        .tint(.blue)
        .onChange(of: selectedTab) { _, newValue in
            commandCenter.goToTab(newValue)
        }
        .onChange(of: commandCenter.requestedTab) { _, newValue in
            selectedTab = newValue
        }

        if #available(iOS 18.0, *) {
            tabs.tabViewStyle(.sidebarAdaptable)
        } else {
            tabs
        }
    }
}

struct RegularEntriesSplitView: View {
    @State private var selectedSection: AppSection? = .home
    @State private var selectedItem: Item?
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            EntriesSidebarView(selectedSection: $selectedSection)
        } content: {
            EntryListView(selectedItem: $selectedItem, showsNavigationDestination: false)
                .navigationTitle("Entries")
        } detail: {
            if let item = selectedItem {
                ItemInfo(item: item)
                    .id(item.id)
                    .navigationTitle("Expense Detail")
            } else {
                ContentUnavailableView("Select an Entry", systemImage: "doc.text", description: Text("Pick an expense from the list to see details."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    columnVisibility = columnVisibility == .all ? .detailOnly : .all
                } label: {
                    Label(
                        columnVisibility == .all ? "Focus Detail" : "Show Columns",
                        systemImage: columnVisibility == .all ? "rectangle.expand.vertical" : "sidebar.left"
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear { columnVisibility = .all }
    }
}

struct RegularAnalyticsSplitView: View {
    @State private var selectedSection: DataViewSection? = .overview
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var inspectorPresented = true
    @State private var selectedCategory: ExpenseCategory?
    @State private var selectedMethod: PaymentMethod?
    @Environment(\.openWindow) private var openWindow

    private var activeFilters: AnalyticsFilterOptions {
        AnalyticsFilterOptions(category: selectedCategory, paymentMethod: selectedMethod)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List([AppSection.data], id: \.self) { section in
                Label("Analytics", systemImage: section.icon)
            }
            .listStyle(.sidebar)
            .navigationTitle("Expense")
        } content: {
            AnalyticsSectionList(selectedSection: $selectedSection)
                .navigationTitle("Analytics")
        } detail: {
            AnalyticsDetailView(selectedSection: selectedSection)
                .environment(\.analyticsFilterOptions, activeFilters)
                .inspector(isPresented: $inspectorPresented) {
                    AnalyticsInspectorView(
                        selectedSection: $selectedSection,
                        selectedCategory: $selectedCategory,
                        selectedMethod: $selectedMethod,
                        onOpenComparisonWindow: {
                            openWindow(id: "comparison-window")
                        }
                    )
                }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    columnVisibility = columnVisibility == .all ? .detailOnly : .all
                } label: {
                    Label(
                        columnVisibility == .all ? "Focus Detail" : "Show Columns",
                        systemImage: columnVisibility == .all ? "rectangle.expand.vertical" : "sidebar.left"
                    )
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    inspectorPresented.toggle()
                } label: {
                    Label(inspectorPresented ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.right")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct AnalyticsInspectorView: View {
    @Binding var selectedSection: DataViewSection?
    @Binding var selectedCategory: ExpenseCategory?
    @Binding var selectedMethod: PaymentMethod?
    let onOpenComparisonWindow: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Analytics") {
                    Picker("Section", selection: $selectedSection) {
                        ForEach(DataViewSection.allCases) { section in
                            Text(section.displayName).tag(Optional(section))
                        }
                    }
                }

                Section("Filters") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All Categories").tag(ExpenseCategory?.none)
                        ForEach(ExpenseCategory.allCases) { category in
                            Text(category.displayName).tag(ExpenseCategory?.some(category))
                        }
                    }

                    Picker("Payment", selection: $selectedMethod) {
                        Text("All Methods").tag(PaymentMethod?.none)
                        ForEach(PaymentMethod.allCases) { method in
                            Text(method.displayName).tag(PaymentMethod?.some(method))
                        }
                    }
                }

                Section("Actions") {
                    Button("Open Comparison in New Window") {
                        onOpenComparisonWindow()
                    }
                }
            }
            .navigationTitle("Inspector")
        }
    }
}

struct EntriesSidebarView: View {
    @Binding var selectedSection: AppSection?
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]

    private var cal: Calendar { Calendar.current }

    private var todayTotal: Double {
        let start = cal.startOfDay(for: Date())
        return items.filter { $0.date >= start }.reduce(0) { $0 + $1.amount }
    }

    private var weekTotal: Double {
        let ago = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return items.filter { $0.date >= ago }.reduce(0) { $0 + $1.amount }
    }

    private var monthTotal: Double {
        let start = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
        return items.filter { $0.date >= start }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        List(selection: $selectedSection) {
            Section {
                Label("Entries", systemImage: AppSection.entry.icon)
                    .tag(AppSection.entry)
            }
            Section("Recent Insights") {
                LabeledContent("Today") {
                    Text("₹\(String(format: "%.0f", todayTotal))")
                        .foregroundStyle(todayTotal > 0 ? .primary : .secondary)
                }
                .selectionDisabled()
                LabeledContent("Last 7 Days") {
                    Text("₹\(String(format: "%.0f", weekTotal))")
                }
                .selectionDisabled()
                LabeledContent("This Month") {
                    Text("₹\(String(format: "%.0f", monthTotal))")
                        .fontWeight(.semibold)
                }
                .selectionDisabled()
                LabeledContent("All Entries") {
                    Text("\(items.count)")
                        .foregroundStyle(.secondary)
                }
                .selectionDisabled()
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Expense")
    }
}

struct AnalyticsSectionList: View {
    @Binding var selectedSection: DataViewSection?
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]

    private var cal: Calendar { Calendar.current }

    private var monthTotal: Double {
        let start = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
        return items.filter { $0.date >= start }.reduce(0) { $0 + $1.amount }
    }

    private var prevMonthTotal: Double {
        let startOfMonth = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
        let startOfPrev = cal.date(byAdding: .month, value: -1, to: startOfMonth) ?? startOfMonth
        return items.filter { $0.date >= startOfPrev && $0.date < startOfMonth }.reduce(0) { $0 + $1.amount }
    }

    private var monthOverMonthChange: Double? {
        guard prevMonthTotal > 0 else { return nil }
        return ((monthTotal - prevMonthTotal) / prevMonthTotal) * 100
    }

    var body: some View {
        List(selection: $selectedSection) {
            ForEach(DataViewSection.allCases) { section in
                HStack(spacing: 14) {
                    Image(systemName: section.icon)
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.displayName)
                            .font(.headline)
                        Text(section.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .tag(section)
            }
            Section("Spending Snapshot") {
                LabeledContent("This Month") {
                    Text("₹\(String(format: "%.0f", monthTotal))")
                        .fontWeight(.semibold)
                }
                .selectionDisabled()
                if prevMonthTotal > 0 {
                    LabeledContent("Last Month") {
                        Text("₹\(String(format: "%.0f", prevMonthTotal))")
                            .foregroundStyle(.secondary)
                    }
                    .selectionDisabled()
                }
                if let change = monthOverMonthChange {
                    LabeledContent("M/M Change") {
                        Text("\(change >= 0 ? "+" : "")\(String(format: "%.1f", change))%")
                            .foregroundStyle(change > 0 ? .red : .green)
                            .fontWeight(.medium)
                    }
                    .selectionDisabled()
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct AnalyticsDetailView: View {
    let selectedSection: DataViewSection?

    var body: some View {
        Group {
            switch selectedSection {
            case .overview:
                OverviewView()
                    .navigationTitle("Overview")
            case .comparison:
                ComparisonView()
                    .navigationTitle("Compare")
            case .trends:
                TrendsView()
                    .navigationTitle("Trends")
            case .healthScore:
                FinancialHealthView()
                    .navigationTitle("Financial Health")
            case .none:
                ContentUnavailableView("Select Analytics", systemImage: "chart.bar", description: Text("Pick an analytics section to view details."))
            }
        }
    }
}

// MARK: - Entry List (Push-detail on iPhone)

struct EntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var commandCenter: AppCommandCenter
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    @Query private var DCS: [DailyCategorySummary]
    @Query private var MCS: [MonthlyCategorySummary]

    private var selectedItemBinding: Binding<Item?>?
    private let showsNavigationDestination: Bool

    init(selectedItem: Binding<Item?>? = nil, showsNavigationDestination: Bool = true) {
        self.selectedItemBinding = selectedItem
        self.showsNavigationDestination = showsNavigationDestination
    }

    @State private var isPresented = false
    @State private var searchText = ""
    @State private var deleteTrigger = false
    @State private var showDeleteAllConfirmation = false
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var showShareError = false
    @State private var shareErrorMessage = ""
    @State private var paymentFilter: PaymentMethodFilter = .all
    @State private var showingImporter = false
    @State private var importResultMessage = ""
    @State private var showImportResult = false
    @State private var importFailures: [ImportFailure] = []
    @State private var editingItem: Item?
    @State private var listIdentity = UUID()
    @FocusState private var isSearchFocused: Bool
    
    private let searchTip = SearchExpensesTip()

    var filteredItems: [Item] {
        let methodFiltered: [Item]
        switch paymentFilter {
        case .all:
            methodFiltered = items
        case .notSet:
            methodFiltered = items.filter { $0.paymentMethod == nil }
        default:
            methodFiltered = items.filter { $0.paymentMethod == paymentFilter.method }
        }

        if searchText.isEmpty { return methodFiltered }
        return methodFiltered.filter { item in
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

            if groupedByDay.isEmpty {
                ContentUnavailableView(
                    "No Entries",
                    systemImage: "tray",
                    description: Text(searchText.isEmpty ? "Add an expense to get started." : "Try a different search or filter.")
                )
            } else {
                ForEach(groupedByDay, id: \.date) { group in
                    Section {
                        ForEach(group.items, id: \.id) { item in
                            entryRow(for: item)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        editingItem = item
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)

                                    Button {
                                        commandCenter.selectedEntryID = item.id
                                        openWindow(id: "entry-detail", value: item.id)
                                    } label: {
                                        Label("Open Window", systemImage: "macwindow")
                                    }
                                    .tint(.indigo)
                                }
                        }
                        .onDelete { offsets in deleteItems(from: group.items, at: offsets) }
                    } header: {
                        Text(group.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    }
                }
            }
        }
        .id(listIdentity)
        .listStyle(.insetGrouped)
        .navigationTitle("Entries")
        .refreshable {
            listIdentity = UUID()
        }
        .navigationDestination(for: Item.self) { item in
            ItemInfo(item: item)
        }
        .searchable(text: $searchText, prompt: "Search expenses…")
        .applySearchFocus($isSearchFocused)
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty { SearchExpensesTip.hasSearched = true }
            listIdentity = UUID()
        }
        .onChange(of: paymentFilter) { _, _ in
            listIdentity = UUID()
        }
        .onChange(of: items.count) { _, _ in
            listIdentity = UUID()
        }
        .onChange(of: commandCenter.addExpenseCommandTick) { _, _ in
            isPresented = true
        }
        .onChange(of: commandCenter.importCSVCommandTick) { _, _ in
            showingImporter = true
        }
        .onChange(of: commandCenter.focusSearchCommandTick) { _, _ in
            isSearchFocused = true
        }
        .onChange(of: commandCenter.editSelectedCommandTick) { _, _ in
            guard let selectedID = commandCenter.selectedEntryID,
                  let selected = items.first(where: { $0.id == selectedID }) else { return }
            editingItem = selected
        }
        .onChange(of: commandCenter.deleteSelectedCommandTick) { _, _ in
            guard let selectedID = commandCenter.selectedEntryID,
                  let selected = items.first(where: { $0.id == selectedID }) else { return }
            ExpenseDataManager.deleteItemAndUpdateSummaries(item: selected, dailySummaries: DCS, monthlySummaries: MCS, context: modelContext)
            commandCenter.selectedEntryID = nil
            if selectedItemBinding?.wrappedValue?.id == selectedID {
                selectedItemBinding?.wrappedValue = nil
            }
            deleteTrigger.toggle()
        }
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.5), trigger: deleteTrigger)
        .sensoryFeedback(.selection, trigger: paymentFilter)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Picker("Payment Method", selection: $paymentFilter) {
                        ForEach(PaymentMethodFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) { showDeleteAllConfirmation = true } label: {
                    Label("Delete All", systemImage: "trash")
                }
                .disabled(items.isEmpty)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { prepareCSVShare() } label: { Label("Share CSV", systemImage: "square.and.arrow.up") }
                    .disabled(items.isEmpty)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingImporter = true } label: { Label("Import CSV", systemImage: "tray.and.arrow.down") }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { isPresented = true } label: { Label("Add Expense", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $isPresented) {
            AddView(isPresented: $isPresented)
        }
        .sheet(item: $editingItem) { item in
            EditEntryView(item: item)
        }
        .confirmationDialog("Delete all entries?", isPresented: $showDeleteAllConfirmation, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) { deleteAllItems() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all expenses and summaries. This action cannot be undone.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
        .alert("Unable to Share", isPresented: $showShareError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(shareErrorMessage)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await importCSV(at: url)
                }
            case .failure(let error):
                importResultMessage = "Import failed: \(error.localizedDescription)"
                importFailures = []
                showImportResult = true
            }
        }
        .alert("CSV Import", isPresented: $showImportResult) {
            Button("OK", role: .cancel) { }
        } message: {
            if importFailures.isEmpty {
                Text(importResultMessage)
            } else {
                Text("\(importResultMessage)\n\nIssues:\n\(importFailures.prefix(5).map { "• Row \($0.row): \($0.reason)" }.joined(separator: "\n"))")
            }
        }
    }

    // MARK: Actions

    @ViewBuilder
    private func entryRow(for item: Item) -> some View {
        if showsNavigationDestination {
            NavigationLink(value: item) {
                EntryRow(item: item)
            }
            .simultaneousGesture(TapGesture().onEnded {
                commandCenter.selectedEntryID = item.id
            })
        } else {
            Button {
                selectedItemBinding?.wrappedValue = item
                commandCenter.selectedEntryID = item.id
            } label: {
                EntryRow(item: item)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

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
                if selectedItemBinding?.wrappedValue?.id == item.id {
                    selectedItemBinding?.wrappedValue = nil
                }
                if commandCenter.selectedEntryID == item.id {
                    commandCenter.selectedEntryID = nil
                }
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

    private func prepareCSVShare() {
        let csvText = makeCSV()
        guard let data = csvText.data(using: .utf8) else {
            shareErrorMessage = "Failed to encode CSV data."
            showShareError = true
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "Expenses-\(formatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
            shareURL = url
            showShareSheet = true
        } catch {
            shareErrorMessage = "Unable to create CSV file."
            showShareError = true
        }
    }

    private func makeCSV() -> String {
        let header = "Date,Amount,Category,Payment Method,Transaction Type,Description"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let rows = items.sorted { $0.date < $1.date }.map { item in
            let dateText = formatter.string(from: item.date)
            let amountText = String(format: "%.2f", item.amount)
            let categoryText = item.category.displayName
            let methodText = item.paymentMethod?.displayName ?? "Not set"
            let transactionTypeText = item.transactionType.displayName
            let descriptionText = item.descriptions
            return [dateText, amountText, categoryText, methodText, transactionTypeText, descriptionText].map(csvEscape).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\n") || value.contains("\"") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    private func importCSV(at url: URL) async {
        do {
            let localURL = try makeLocalImportCopy(from: url)
            let text = try String(contentsOf: localURL, encoding: .utf8)
            let lines = text
                .components(separatedBy: CharacterSet.newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            guard let headerLine = lines.first else {
                await MainActor.run {
                    importResultMessage = "No rows found in file."
                    importFailures = []
                    showImportResult = true
                }
                return
            }

            let header = parseCSVRow(headerLine).map { normalizeHeader($0) }
            let dateIdx = header.firstIndex(of: "date")
            let amountIdx = header.firstIndex(of: "amount")
            let categoryIdx = header.firstIndex(of: "category")
            let methodIdx = header.firstIndex(of: "paymentmethod")
            let transactionTypeIdx = header.firstIndex(of: "transactiontype")
            let descIdx = header.firstIndex(of: "description") ?? header.firstIndex(of: "desc")

            var imported = 0
            var failures: [ImportFailure] = []

            for (offset, line) in lines.dropFirst().enumerated() {
                let rowNumber = offset + 2
                let cols = parseCSVRow(line)
                if cols.isEmpty {
                    failures.append(ImportFailure(row: rowNumber, reason: "Empty row", raw: line))
                    continue
                }

                let dateText = dateIdx.flatMap { cols[safe: $0] } ?? ""
                let categoryText = categoryIdx.flatMap { cols[safe: $0] } ?? ""
                let methodText = methodIdx.flatMap { cols[safe: $0] } ?? ""
                let transactionTypeText = transactionTypeIdx.flatMap { cols[safe: $0] } ?? ""
                let descriptionText = descIdx.flatMap { cols[safe: $0] } ?? ""
                let amountText = amountIdx.flatMap { cols[safe: $0] } ?? ""

                let parsedAmount = parseAmountOrZero(amountText)
                let date = parseDateOrToday(dateText)
                let category = mapCategory(categoryText)
                let method = mapPaymentMethod(methodText)
                let transactionType = mapTransactionType(transactionTypeText)

                let item = Item(
                    id: UUID(),
                    date: date,
                    amount: parsedAmount,
                    descriptions: descriptionText,
                    category: category,
                    paymentMethod: method,
                    transactionType: transactionType
                )

                await MainActor.run {
                    ExpenseDataManager.addItemAndUpdateSummaries(
                        item: item,
                        dailySummaries: DCS,
                        monthlySummaries: MCS,
                        context: modelContext
                    )
                }

                imported += 1
            }

            await MainActor.run {
                importFailures = failures
                importResultMessage = "Imported: \(imported), Issues: \(failures.count)"
                showImportResult = true
            }
        } catch {
            await MainActor.run {
                importResultMessage = "Import failed: \(error.localizedDescription)"
                importFailures = []
                showImportResult = true
            }
        }
    }

    private func makeLocalImportCopy(from pickedURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let didStartScopedAccess = pickedURL.startAccessingSecurityScopedResource()
        defer {
            if didStartScopedAccess {
                pickedURL.stopAccessingSecurityScopedResource()
            }
        }

        let importsDirectory = fileManager.temporaryDirectory.appendingPathComponent("CSVImports", isDirectory: true)
        if !fileManager.fileExists(atPath: importsDirectory.path) {
            try fileManager.createDirectory(at: importsDirectory, withIntermediateDirectories: true)
        }

        let destinationURL = importsDirectory.appendingPathComponent("\(UUID().uuidString)-\(pickedURL.lastPathComponent)")

        do {
            try fileManager.copyItem(at: pickedURL, to: destinationURL)
            return destinationURL
        } catch {
            var coordinatorError: NSError?
            var readCopyError: Error?
            let coordinator = NSFileCoordinator()

            coordinator.coordinate(readingItemAt: pickedURL, options: [], error: &coordinatorError) { readableURL in
                do {
                    let data = try Data(contentsOf: readableURL)
                    try data.write(to: destinationURL, options: .atomic)
                } catch {
                    readCopyError = error
                }
            }

            if let readCopyError {
                throw readCopyError
            }

            if let coordinatorError {
                throw coordinatorError
            }

            throw error
        }
    }

    private func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var index = row.startIndex

        while index < row.endIndex {
            let char = row[index]
            if char == "\"" {
                let nextIndex = row.index(after: index)
                if inQuotes, nextIndex < row.endIndex, row[nextIndex] == "\"" {
                    current.append("\"")
                    index = nextIndex
                } else {
                    inQuotes.toggle()
                }
            } else if char == ",", !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(char)
            }
            index = row.index(after: index)
        }

        result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return result
    }

    private func normalizeHeader(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private func parseAmountOrZero(_ value: String) -> Double {
        let sanitized = value
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(sanitized) ?? 0
    }

    private func parseDateOrToday(_ value: String) -> Date {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            return Date()
        }

        // Accept ISO datetime without timezone: 2026-03-01T22:06:00
        let isoNoTZ = DateFormatter()
        isoNoTZ.locale = Locale(identifier: "en_US_POSIX")
        isoNoTZ.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = isoNoTZ.date(from: cleaned) {
            return date
        }

        // Fallback to flexible ISO8601 parser
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: cleaned) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = ["yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy", "yyyy-MM-dd HH:mm:ss"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) {
                return date
            }
        }

        return Date()
    }

    private func mapCategory(_ raw: String) -> ExpenseCategory {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            return .miscellaneous
        }

        if let exact = ExpenseCategory.allCases.first(where: { $0.rawValue.lowercased() == normalized }) {
            return exact
        }

        if let displayMatch = ExpenseCategory.allCases.first(where: { $0.displayName.lowercased() == normalized }) {
            return displayMatch
        }

        return .miscellaneous
    }

    private func mapPaymentMethod(_ raw: String) -> PaymentMethod {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            return .other
        }

        if let exact = PaymentMethod.allCases.first(where: { $0.rawValue.lowercased() == normalized }) {
            return exact
        }

        if let displayMatch = PaymentMethod.allCases.first(where: { $0.displayName.lowercased() == normalized }) {
            return displayMatch
        }

        return .other
    }

    private func mapTransactionType(_ raw: String) -> TransactionType {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            return .expense
        }

        if let exact = TransactionType.allCases.first(where: { $0.rawValue.lowercased() == normalized }) {
            return exact
        }

        if let displayMatch = TransactionType.allCases.first(where: { $0.displayName.lowercased() == normalized }) {
            return displayMatch
        }

        if normalized.contains("bill")
            || normalized.contains("creditcard")
            || (normalized.contains("credit") && normalized.contains("card") && normalized.contains("payment")) {
            return .creditCardBillPayment
        }
        if normalized.contains("transfer") {
            return .transfer
        }

        return .expense
    }
}

private struct ImportFailure: Identifiable {
    let id = UUID()
    let row: Int
    let reason: String
    let raw: String
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension View {
    @ViewBuilder
    func applySearchFocus(_ focused: FocusState<Bool>.Binding) -> some View {
        if #available(iOS 18.0, *) {
            self.searchFocused(focused)
        } else {
            self
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

struct EditEntryView: View {
    let item: Item

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var DCS: [DailyCategorySummary]
    @Query private var MCS: [MonthlyCategorySummary]

    @State private var date: Date
    @State private var amountText: String
    @State private var descriptionText: String
    @State private var selectedCategory: ExpenseCategory
    @State private var selectedTransactionType: TransactionType
    @State private var selectedPaymentMethod: PaymentMethod
    @State private var showValidationAlert = false

    init(item: Item) {
        self.item = item
        _date = State(initialValue: item.date)
        _amountText = State(initialValue: String(format: "%.0f", item.amount))
        _descriptionText = State(initialValue: item.descriptions)
        _selectedCategory = State(initialValue: item.category)
        _selectedTransactionType = State(initialValue: item.transactionType)
        _selectedPaymentMethod = State(initialValue: item.paymentMethod ?? .other)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.numberPad)
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }

                Section("Date & Time") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
                }

                Section("Payment Method") {
                    Picker("Payment Method", selection: $selectedPaymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                }

                Section("Transaction Type") {
                    Picker("Transaction Type", selection: $selectedTransactionType) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Description") {
                    TextField("Description", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Edit Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Invalid Input", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid amount greater than 0.")
            }
        }
    }

    private func saveChanges() {
        guard let amount = Double(amountText), amount > 0 else {
            showValidationAlert = true
            return
        }

        let updated = Item(
            id: item.id,
            date: date,
            amount: amount,
            descriptions: descriptionText,
            category: selectedCategory,
            paymentMethod: selectedPaymentMethod,
            transactionType: selectedTransactionType
        )

        ExpenseDataManager.deleteItemAndUpdateSummaries(
            item: item,
            dailySummaries: DCS,
            monthlySummaries: MCS,
            context: modelContext
        )

        ExpenseDataManager.addItemAndUpdateSummaries(
            item: updated,
            dailySummaries: DCS,
            monthlySummaries: MCS,
            context: modelContext
        )

        dismiss()
    }
}

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
#endif
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
    .environmentObject(AppCommandCenter())
        .modelContainer(for: Item.self, inMemory: true)
}
