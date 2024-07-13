//
//  ContentView.swift
//  Expense
//
//  Created by Harshit Agarwal on 06/07/24.
//

import SwiftUI
import SwiftData
import Combine

enum Section {
    case entry
    case data
    case aboutUs
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
    @State private var selectedSection: Section?

    var body: some View {
        NavigationSplitView{
            List {
                NavigationLink(destination: EntryView(isPresented: $isPresented), tag: Section.entry, selection: $selectedSection) {
                    SidebarLabel(label: "Entry", isSelected: .constant(selectedSection == .entry))
                                }
                NavigationLink(destination: DataView(), tag: Section.data, selection: $selectedSection) {
                    SidebarLabel(label: "Data", isSelected: .constant(selectedSection == .data))
                                }
                NavigationLink(destination: AboutUsView(), tag: Section.aboutUs, selection: $selectedSection) {
                    SidebarLabel(label: "About us", isSelected: .constant(selectedSection == .aboutUs))
                                }
        }
        .listStyle(.sidebar)
        .navigationTitle("Menu")
        }content:{
            switch selectedSection {
            case .entry:
                EntryView(isPresented: $isPresented)
                .navigationTitle("Entry")
            case .data:
                Text("Data")
            case .aboutUs:
                Text("About us")
            case .none:
                Text("None")
            }
        } detail: {
            ZStack{
                //Do something when its empty
                VStack{
                    //Primary
                    Text("Select an item")
                }
                AddButton(isPresented: $isPresented)
            }
            .padding()
            
        }
    }

    
}


struct EntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @Binding var isPresented: Bool
    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink {
                    ZStack{
                        VStack{
                            //Primary
                            ItemInfo(item: item)
                        }
                        AddButton(isPresented: $isPresented)
                    }
                } label: {
                    //Sidebar
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
struct DataView: View {
    var body: some View {
        Text("Data View")
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
