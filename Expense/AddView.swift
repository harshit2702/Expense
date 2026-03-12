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
    @Environment(\.dismiss) private var dismiss
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
        NavigationView {
            Form {
                // MARK: Amount
                Section("Amount") {
                    HStack {
                        Text("₹")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $amount)
                            .keyboardType(.numberPad)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .onReceive(Just(amount)) { newValue in
                                let filtered = newValue.filter { "0123456789".contains($0) }
                                if filtered != newValue { amount = filtered }
                            }
                    }
                }

                // MARK: Category
                Section("Category") {
                    TextField("Search category…", text: $searchCategory)
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(searchResults) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // MARK: Date & Time
                Section("Date & Time") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                    DatePicker("Time", selection: $date, displayedComponents: [.hourAndMinute])
                }

                // MARK: Description
                Section("Description") {
                    TextField("What was this expense for?", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Invalid Input", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
            .sensoryFeedback(.success, trigger: saveTrigger)
        }
    }

    // MARK: - Save

    private func saveExpense() {
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

    var searchResults: [ExpenseCategory] {
        if searchCategory.isEmpty {
            return ExpenseCategory.allCases
        } else {
            return ExpenseCategory.allCases.filter {
                $0.rawValue.localizedCaseInsensitiveContains(searchCategory) ||
                $0.rawValue.localizedCaseInsensitiveContains("miscellaneous")
            }
        }
    }
}

#Preview {
    AddView(isPresented: .constant(true))
}
