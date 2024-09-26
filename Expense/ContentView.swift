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
            for i in 0..<(sampleItems.count){
                modelContext.insert(sampleItems[i])
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
    private func deleteAllItems() {
        withAnimation {
            for item in items {
                modelContext.delete(item)
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
