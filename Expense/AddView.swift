//
//  AddView.swift
//  Expense
//
//  Created by Harshit Agarwal on 12/07/24.
//

import SwiftUI
import Combine
import SwiftData
import TipKit

struct AddView: View {
    @State var date = Date()
    @State var amount = ""
    @State var description = ""
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @Query private var DCS: [DailyCategorySummary]
    @Query private var MCS: [MonthlyCategorySummary]
    @Binding var isPresented: Bool
    @State private var selectedCategory: ExpenseCategory = .food
    @State private var searchCategory = ""
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var saveTrigger = false


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
                            TextField("Description", text: $description)
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
                            Text("You selected: \(selectedCategory.displayName)")
                                .font(.title3)
                            
                            Picker("Please choose a category", selection: $selectedCategory) {
                                ForEach(searchResults) { category in
                                                Text(category.displayName).tag(category)
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
                            // Form validation
                            guard let parsedAmount = Double(amount), parsedAmount > 0 else {
                                validationMessage = "Please enter a valid amount greater than 0."
                                showValidationAlert = true
                                return
                            }
                            
                            let newItem = Item(id: UUID(), date: date, amount: parsedAmount, descriptions: description, category: selectedCategory)
                            ExpenseDataManager.addItemAndUpdateSummaries(
                                item: newItem,
                                dailySummaries: DCS,
                                monthlySummaries: MCS,
                                context: modelContext
                            )
                            AddExpenseTip.hasAddedExpense = true
                            saveTrigger.toggle()
                            isPresented = false
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
            .alert("Invalid Input", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
            .sensoryFeedback(.success, trigger: saveTrigger)
        }
    }
    
    var searchResults: [ExpenseCategory] {
        if searchCategory.isEmpty {
            return ExpenseCategory.allCases
            } else {
                return ExpenseCategory.allCases.filter { $0.rawValue.localizedCaseInsensitiveContains(searchCategory) || $0.rawValue.localizedCaseInsensitiveContains("miscellaneous") }
            }
        }
}

#Preview {
    AddView( isPresented: .constant(true))
}
