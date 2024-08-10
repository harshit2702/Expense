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
    case data
    case aboutUs
    
    var id: String { self.rawValue }
    
    var name: String {
            switch self {
            case .entry: return "Entry"
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

    var body: some View {
        NavigationSplitView{
            List(Section.allCases, id: \.self, selection: $selectedSection) {section in
                SidebarLabel(label: section.name, isSelected: .constant(selectedSection == section))
        }
        .listStyle(.sidebar)
        .navigationTitle("Menu")
        }content:{
            switch selectedSection {
            case .entry:
                EntryView(isPresented: $isPresented, selectedItem: $selectedItem)
                .navigationTitle("Entry")
            case .data:
                DataView()
                    .navigationTitle("Data")
            case .aboutUs:
                Text("About us")
            case .none:
                Text("None")
            }
        } detail: {
            switch selectedSection {
            case .entry:
                ZStack{
                    VStack{
                        //Primary
                        if let item = selectedItem {
                            ItemInfo(item: item)
                                .id(item.id) // Add this line to force view update when item changes
                        }
                        else{
                            Text("No Entry")
                        }
                    }
                    AddButton(isPresented: $isPresented)
                }
            case .data:
                Text("Data Detail")
            case .aboutUs:
                Text("About us Detail")
            case .none:
                Text("None")
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
                    HStack{
                        Text(item.category.rawValue)
                            .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                        Spacer()
                        Text(String(item.amount) + "INR")
                            .font(.title3)
                            .bold()
                    }
                }
            }
            .onDelete(perform: deleteItems)
            .sheet(isPresented: $isPresented) {
                AddView(isPresented: $isPresented)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem {
                Button(action: addItem) {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Entry")

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
