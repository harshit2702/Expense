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
    @Query private var DCS: [DailyCategorySummary]
    @Query private var MCS: [MonthlyCategorySummary]
    @Binding var isPresented: Bool
    @State private var selectedCategory: ExpenseCategory = .food
    @State private var selectedPaymentMethod: PaymentMethod = .upi
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
                    Text("Selected: \(selectedCategory.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ExpenseCategory.primaryCases) { category in
                                CategoryChip(
                                    title: category.displayName,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                }

                // MARK: Date & Time
                Section("Date & Time") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .labelsHidden()

                    DatePicker("Time", selection: $date, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxHeight: 110)
                }

                // MARK: Payment Method
                Section("Payment Method") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(PaymentMethod.allCases) { method in
                            PaymentMethodChip(
                                title: method.displayName,
                                isSelected: selectedPaymentMethod == method
                            ) {
                                selectedPaymentMethod = method
                            }
                        }
                    }
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

        let newItem = Item(
            id: UUID(),
            date: date,
            amount: parsedAmount,
            descriptions: description,
            category: selectedCategory,
            paymentMethod: selectedPaymentMethod
        )
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

}

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct PaymentMethodChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddView(isPresented: .constant(true))
}
