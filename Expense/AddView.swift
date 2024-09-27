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
    @Binding var isPresented: Bool
    @State private var selectedCategory: Categorys = .food

    var body: some View {
        GeometryReader{ geo in
            ZStack{
                List{
                    HStack{
                        VStack{
//                            Section("Date and Time"){
                                
                                DatePicker(selection: $date, displayedComponents: [.date]){
                                    Text("Date")
                                }
                                .datePickerStyle(.graphical)
                                DatePicker(selection: $date, displayedComponents: [.hourAndMinute]){
                                }
                                .datePickerStyle(.wheel)
                                //                            .offset(x: -(geo.size.width / 4))
//                            }
                        }.frame(width: geo.size.width / 2)
                        Spacer(minLength: 20)
                        VStack{
//                            Section("Category"){
                                Picker("Please choose a category", selection: $selectedCategory) {
                                                ForEach(Categorys.allCases) { category in
                                                    Text(category.rawValue.capitalized).tag(category)
                                                }
                                            }
                                            .pickerStyle(WheelPickerStyle()) // You can choose different picker styles if needed
                                Text("You selected: \(selectedCategory.rawValue.capitalized)")
                                    .font(.title3)
//                            }
                        }
                    }
                    
//                    Section("Amount"){
                        TextField("00.00", text: $amount)
                            .keyboardType(.numberPad)
                            .onReceive(Just(amount)) { newValue in
                                let filtered = newValue.filter { "0123456789".contains($0) }
                                if filtered != newValue {
                                    amount = filtered
                                }
                            }
                            .frame(minHeight: 40)
//                    }
//                    Section("Discription"){
                        TextField("Discription", text: $description)
                            .frame(minHeight: 250)
//                    }
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
                                // Fetch or update Daily Summary
                                if let dailySummary = try modelContext.fetch(FetchDescriptor<DailyCategorySummary>(predicate: #Predicate { $0.date == startOfDay && $0.category == category })).first {
                                    dailySummary.totalAmount += amount
                                } else {
                                    let newDailySummary = DailyCategorySummary(category: category, date: startOfDay, totalAmount: amount)
                                    modelContext.insert(newDailySummary)
                                }

                                // Fetch or update Monthly Summary
                                let startOfMonth = Calendar.current.dateInterval(of: .month, for: date)!.start
                                if let monthlySummary = try modelContext.fetch(FetchDescriptor<MonthlyCategorySummary>(predicate: #Predicate { $0.date == startOfMonth && $0.category == category })).first {
                                    monthlySummary.totalAmount += amount
                                } else {
                                    let newMonthlySummary = MonthlyCategorySummary(category: category, date: startOfMonth, totalAmount: amount)
                                    modelContext.insert(newMonthlySummary)
                                }

                                // Fetch or update Yearly Summary
                                let startOfYear = Calendar.current.dateInterval(of: .year, for: date)!.start
                                if let yearlySummary = try modelContext.fetch(FetchDescriptor<YearlyCategorySummary>(predicate: #Predicate { $0.date == startOfYear && $0.category == category })).first {
                                    yearlySummary.totalAmount += amount
                                } else {
                                    let newYearlySummary = YearlyCategorySummary(category: category, date: startOfYear, totalAmount: amount)
                                    modelContext.insert(newYearlySummary)
                                }

                                // Save the context
                                try modelContext.save()

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
}

#Preview {
    AddView( isPresented: .constant(true))
}
