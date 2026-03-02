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

enum Section: String, Identifiable, CaseIterable {
    case entry
    case overview
    case data
    case budget
    case aboutUs
    
    var id: String { self.rawValue }
    
    var name: String {
        switch self {
        case .entry: return "Entry"
        case .overview: return "Overview"
        case .data: return "Data"
        case .budget: return "Budget"
        case .aboutUs: return "About Us"
        }
    }
}

struct AddButton: View {
    @Binding var isPresented: Bool
    private let addExpenseTip = AddExpenseTip()

    var body: some View {
        VStack{
            Spacer()
            HStack{
                Spacer()
                Button{
                    isPresented = true
                }label: {
                    ZStack{
                        Image(systemName: "plus")
                            .resizable()
                            .padding()
                            .foregroundStyle(.primary)
                        RoundedRectangle(cornerRadius: 25.0)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    }
                    .frame(width: 100,height: 100)
                }
                .popoverTip(addExpenseTip, arrowEdge: .bottom)
            }
        }
        .padding()
    }
}
struct SidebarLabel: View {
    @State var label: String
    @Binding var isSelected: Bool
    var body: some View {
        ZStack{
            RoundedRectangle(cornerRadius: 10.0)
                .fill(isSelected ? Color.blue.opacity(0.6) : .clear)
                .background(
                    RoundedRectangle(cornerRadius: 10.0)
                        .fill(.ultraThinMaterial)
                )
            Text(label)
        }
    }
}

struct ContentView: View {
    
    @State private var isPresented = false
    @State private var selectedSection: Section? = .entry
    @State private var selectedItem: Item?
    @State private var isEntrySidebarVisible: Bool = true // Control sidebar visibility

    var body: some View {
        NavigationSplitView {
            // Main Sidebar
            List(Section.allCases, id: \.self, selection: $selectedSection) { section in
                SidebarLabel(label: section.name, isSelected: .constant(selectedSection == section))
            }
            .frame(minWidth: 300, idealWidth: 350, maxWidth: 400)
            .listStyle(.sidebar)
        } detail: {
            switch selectedSection {
            case .entry:
                ZStack {
                    HStack {
                        if isEntrySidebarVisible {
                            // Sidebar for Entries
                            EntryView(isPresented: $isPresented, selectedItem: $selectedItem)
                                .frame(minWidth: 300, idealWidth: 350, maxWidth: 400) // Set max width for the sidebar
                                .transition(.move(edge: .leading)) // Animate sidebar appearance/disappearance
                        }
                        
                        // Detail View for Entry
                        VStack {
                            if let item = selectedItem {
                                ItemInfo(item: item)
                                    .id(item.id)
                                    .padding()
                            } else {
                                Text("Select an entry from the sidebar")
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    AddButton(isPresented: $isPresented)
                }
                .toolbar {
                    // Add a button to toggle the sidebar
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            withAnimation {
                                isEntrySidebarVisible.toggle()
                            }
                        }) {
                            Image(systemName: isEntrySidebarVisible ? "chevron.left" : "chevron.right")
                        }
                    }
                }
                .navigationTitle("Entry")
                
            case .data:
                DataView()
                    .navigationTitle("Data")
            case .budget:
                BudgetView()
                    .navigationTitle("Budget")
            case .aboutUs:
                AboutUsView()
                    .navigationTitle("About Us")
            case .some(.overview):
                OverviewView()
                    .navigationTitle("Overview")
            case .none:
                Text("Select a section")
            }
        }
    }
}




struct EntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    @Query private var DCS: [DailyCategorySummary]
    @Query private var MCS: [MonthlyCategorySummary]
    @Binding var isPresented: Bool
    @Binding var selectedItem: Item?
    @State private var searchText = ""
    @State private var deleteTrigger = false
    private let searchTip = SearchExpensesTip()
    
    var filteredItems: [Item] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { item in
            item.descriptions.localizedCaseInsensitiveContains(searchText) ||
            item.category.rawValue.localizedCaseInsensitiveContains(searchText) ||
            String(format: "%.2f", item.amount).contains(searchText)
        }
    }
    
    var body: some View {
        List {
            TipView(searchTip)
            ForEach(filteredItems, id: \.id) { item in
                Button{
                    selectedItem = item
                }label: {
                    SidebarLabel(label: "\(item.category.displayName) - \(String(format: "%.2f", item.amount)) \u{20B9}", isSelected: .constant(selectedItem?.id == item.id))
                        .frame(maxWidth: .infinity)
                }
            }
            .onDelete(perform: deleteItems)
            .sheet(isPresented: $isPresented) {
                AddView(isPresented: $isPresented)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "Search expenses...")
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty {
                SearchExpensesTip.hasSearched = true
            }
        }
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.5), trigger: deleteTrigger)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: deleteAllItems) {
                        Label("Delete All", systemImage: "trash")
                    }
                }
            ToolbarItem {
                Button(action: addItem) {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Entries")

    }
    private func addItem() {
        withAnimation {
            for i in 0..<(sampleItems.count) {
                let item = sampleItems[i]
                ExpenseDataManager.addItemAndUpdateSummaries(
                    item: item,
                    dailySummaries: DCS,
                    monthlySummaries: MCS,
                    context: modelContext
                )
            }
        }
    }


    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let item = filteredItems[index]
                ExpenseDataManager.deleteItemAndUpdateSummaries(
                    item: item,
                    dailySummaries: DCS,
                    monthlySummaries: MCS,
                    context: modelContext
                )
            }
            deleteTrigger.toggle()
        }
    }

    private func deleteAllItems() {
        withAnimation {
            ExpenseDataManager.deleteAllData(
                items: items,
                dailySummaries: DCS,
                monthlySummaries: MCS,
                context: modelContext
            )
            deleteTrigger.toggle()
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
                
                Text("Version 1.2.0 — iOS 26 Ready")
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
                    FeatureRow(icon: "plus.circle.fill", text: "Track daily expenses with 60+ categories")
                    FeatureRow(icon: "chart.pie.fill", text: "Visual spending overview with pie charts")
                    FeatureRow(icon: "chart.bar.fill", text: "Weekly, monthly, and yearly bar charts")
                    FeatureRow(icon: "arrow.left.arrow.right", text: "Compare spending across periods")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Track spending trends over time")
                    FeatureRow(icon: "target", text: "Set and monitor category budgets")
                    FeatureRow(icon: "magnifyingglass", text: "Search and filter expenses")
                    FeatureRow(icon: "hand.tap.fill", text: "Haptic sensory feedback on actions")
                    FeatureRow(icon: "lightbulb.fill", text: "TipKit onboarding tips")
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
