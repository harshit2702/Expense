//
//  ContentView.swift
//  Expense
//
//  Created by Harshit Agarwal on 06/07/24.
//

import SwiftUI
import SwiftData
import Combine

enum Section:String, Identifiable, CaseIterable {
    case entry
    case overview
    case data
    case aboutUs
    
    var id: String { self.rawValue }
    
    var name: String {
            switch self {
            case .entry: return "Entry"
            case .overview: return "Overview"
            case .data: return "Data"
            case .aboutUs: return "About Us"
            }
        }
}

struct AddButton: View {
    @Binding var isPresented: Bool
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
                        RoundedRectangle(cornerRadius: 25.0)
                            .fill(Color.secondary.opacity(0.5))
                    }
                    .frame(width: 100,height: 100)
                }
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
                .fill(isSelected ? Color.blue :  Color.secondary)
                .opacity(0.5)
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
            case .aboutUs:
                Text("About Us")
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
    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                Button{
                    selectedItem = item
                }label: {
                    // Reuse SidebarLabel style for each entry
                    SidebarLabel(label: "\(item.category.rawValue) - \(String(item.amount)) INR", isSelected: .constant(selectedItem?.id == item.id))
                        .frame(maxWidth: .infinity)
                }
            }
            .onDelete(perform: deleteItems)
            .sheet(isPresented: $isPresented) {
                AddView(isPresented: $isPresented)
            }
        }
        .listStyle(.sidebar)
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
                modelContext.insert(item)
                
                let date = item.date
                let amount = item.amount
                let category = item.category


                let startOfDay = Calendar.current.startOfDay(for: date)

                do {
                    // Daily Summary
                    if let dailySummary = DCS.first(where: { $0.date == startOfDay && $0.category == category }){
                        dailySummary.totalAmount += amount
                    } else {
                        let newDailySummary = DailyCategorySummary(category: category, date: startOfDay, totalAmount: amount)
                        modelContext.insert(newDailySummary)
                    }

                    // Monthly Summary - using MCS query results
                    let startOfMonth = Calendar.current.dateInterval(of: .month, for: date)!.start
                    if let monthlySummary = MCS.first(where: { $0.date == startOfMonth && $0.category == category }) {
                        monthlySummary.totalAmount += amount
                    } else {
                        let newMonthlySummary = MonthlyCategorySummary(category: category, date: startOfMonth, totalAmount: amount)
                        modelContext.insert(newMonthlySummary)
                    }

                    // Save context
                    try modelContext.save()
                    print("Context saved successfully")

                } catch {
                    print("Failed to save or fetch data: \(error)")
                }
            }
        }
    }


    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let item = items[index]
                let date = item.date
                let category = item.category
                let amount = item.amount
                
                // Delete the item
                modelContext.delete(item)
                
                // Update Daily Summary
                let startOfDay = Calendar.current.startOfDay(for: date)
                do{
                    if let dailySummary = DCS.first(where: { $0.date == startOfDay && $0.category == category }){
                        dailySummary.totalAmount -= amount
                        if dailySummary.totalAmount <= 0 {
                            modelContext.delete(dailySummary) // Remove if no more spending for the day
                        }
                    }
                    
                    // Update Monthly Summary
                    let startOfMonth = Calendar.current.dateInterval(of: .month, for: date)!.start
                    if let monthlySummary = MCS.first(where: { $0.date == startOfMonth && $0.category == category }){
                        monthlySummary.totalAmount -= amount
                        if monthlySummary.totalAmount <= 0 {
                            modelContext.delete(monthlySummary)
                        }
                    }
                    // Save the context
                    try modelContext.save()

                }catch {
                    // Handle the error appropriately
                    print("Failed to save or fetch data: \(error)")
                }

            }
        }
    }

    private func deleteAllItems() {
        withAnimation {
            // Reduce amounts for DailyItems and MonthlyItems
            for item in items{
                // Delete the item
                modelContext.delete(item)
                do{
                    // Save the context
                    try modelContext.save()
                }catch {
                    // Handle the error appropriately
                    print("Failed to save or fetch data: \(error)")
                }
            }
            for item in DCS{
                // Delete the item
                modelContext.delete(item)
                do{
                    // Save the context
                    try modelContext.save()
                }catch {
                    // Handle the error appropriately
                    print("Failed to save or fetch data: \(error)")
                }
            }
            for item in MCS{
                // Delete the item
                modelContext.delete(item)
                do{
                    // Save the context
                    try modelContext.save()
                }catch {
                    // Handle the error appropriately
                    print("Failed to save or fetch data: \(error)")
                }
            }
            
        }
    }

}
struct AboutUsView: View {
    var body: some View {
        Text("About Us View")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
