//
//  AddView.swift
//  Expense
//
//  Created by Harshit Agarwal on 12/07/24.
//

import SwiftUI
import Combine
import SwiftData

struct AddView: View {
    @State var date = Date()
    @State var amount = ""
    @State var description = ""
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @Query private var DCS: [DailyCategorySummary]
    @Query private var MCS: [MonthlyCategorySummary]
    @Binding var isPresented: Bool
    @State private var selectedCategory: Categorys = .food
    @State private var searchCategory = ""


    var body: some View {
        GeometryReader{ geo in
            ZStack{
                List{
                    HStack{
                        VStack{
                            TextField("00.00", text: $amount)
                                .keyboardType(.numberPad)
                                .onReceive(Just(amount)) { newValue in
                                    let filtered = newValue.filter { "0123456789".contains($0) }
                                    if filtered != newValue {
                                        amount = filtered
                                    }
                                }
                                .padding(.leading)
                                .frame(minHeight: 40.0)
                                .background(Color.gray.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 10.0))
                            TextField("Discription", text: $description)
                                .padding(.leading)
                                .frame(minHeight: 250)
                                .background(Color.gray.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 10.0))
                            
                        }
                        .frame(width: geo.size.width / 2)
//                        Spacer(minLength: 20)
                        VStack{
                            TextField("Search Category", text: $searchCategory)
                                                                .padding(10)
                                                                .background(Color.gray.opacity(0.3))
                                                                .clipShape(RoundedRectangle(cornerRadius: 10.0))
                            Text("You selected: \(selectedCategory.rawValue.capitalized)")
                                .font(.title3)
                            
                            Picker("Please choose a category", selection: $selectedCategory) {
                                ForEach(searchResults) { category in
                                                Text(category.rawValue.capitalized).tag(category)
                                            }
                                        }
                                        .pickerStyle(WheelPickerStyle()) // You can choose different picker styles if needed
                        }
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 5.0))
                    }
                    VStack{
                        DatePicker(selection: $date, displayedComponents: [.date]){
                            Text("Date")
                        }
                        .datePickerStyle(.graphical)
                        DatePicker(selection: $date, displayedComponents: [.hourAndMinute]){
                        }
                        .datePickerStyle(.wheel)
                    }
                }
                .padding()
                VStack{
                    HStack{
                        Spacer()
                        Button{
                            let newItem = Item(id: UUID(), date: date, amount: Double(amount) ?? 0.0, descriptions: description, category: selectedCategory)
                            modelContext.insert(newItem)
                            var date = newItem.date
                            var amount = newItem.amount
                            var category = newItem.category

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
                                // Handle the error appropriately
                                print("Failed to save or fetch data: \(error)")
                            }
                        }
label: {
                            ZStack{
                                RoundedRectangle(cornerRadius: 10.0)
                                    .opacity(0.5)
                                Text("save")
                                    .foregroundStyle(Color.primary)
                                    .padding(.vertical)
                            }
                            .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/,height: 20)
                            .offset(x: geo.size.width * -0.05)

                        }
                    }
                    Spacer()
                }
            }
            .offset(y: geo.size.height * 0.1)
            
        }
    }
    
    var searchResults: [Categorys] {
        if searchCategory.isEmpty {
            return Categorys.allCases
            } else {
                return Categorys.allCases.filter { $0.rawValue.localizedCaseInsensitiveContains(searchCategory) || $0.rawValue.localizedCaseInsensitiveContains("miscellaneous") }
            }
        }
}

#Preview {
    AddView( isPresented: .constant(true))
}
