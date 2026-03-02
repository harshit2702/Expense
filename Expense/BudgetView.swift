//
//  BudgetView.swift
//  Expense
//
//  Created by Harshit Agarwal on 01/03/26.
//

import SwiftUI
import SwiftData
import TipKit

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    @State private var showAddBudget = false
    @State private var deleteTrigger = false
    private let budgetTip = SetBudgetTip()
    
    var body: some View {
        List {
            TipView(budgetTip)
            if budgets.isEmpty {
                ContentUnavailableView(
                    "No Budgets Set",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("Tap + to add a monthly budget for any category.")
                )
            } else {
                // Summary Section
                SwiftUI.Section("Monthly Summary") {
                    HStack {
                        Text("Total Budget")
                        Spacer()
                        Text("₹\(String(format: "%.0f", totalBudget))")
                            .fontWeight(.bold)
                    }
                    HStack {
                        Text("Total Spent")
                        Spacer()
                        Text("₹\(String(format: "%.0f", totalSpent))")
                            .fontWeight(.bold)
                            .foregroundStyle(totalSpent > totalBudget ? .red : .primary)
                    }
                    HStack {
                        Text("Remaining")
                        Spacer()
                        let remaining = totalBudget - totalSpent
                        Text("₹\(String(format: "%.0f", remaining))")
                            .fontWeight(.bold)
                            .foregroundStyle(remaining < 0 ? .red : .green)
                    }
                }
                
                // Budget Items
                SwiftUI.Section("Category Budgets") {
                    ForEach(budgets) { budget in
                        BudgetRow(
                            budget: budget,
                            spending: currentMonthSpending(for: budget.category)
                        )
                    }
                    .onDelete(perform: deleteBudgets)
                }
                
                // Over Budget Alerts
                let overBudgetItems = budgets.filter { currentMonthSpending(for: $0.category) > $0.monthlyLimit }
                if !overBudgetItems.isEmpty {
                    SwiftUI.Section("Over Budget") {
                        ForEach(overBudgetItems) { budget in
                            let spent = currentMonthSpending(for: budget.category)
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(budget.category.displayName)
                                Spacer()
                                Text("+₹\(String(format: "%.0f", spent - budget.monthlyLimit))")
                                    .foregroundStyle(.red)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddBudget = true } label: {
                    Label("Add Budget", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddBudget) {
            AddBudgetView()
        }
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.5), trigger: deleteTrigger)
    }
    
    private var totalBudget: Double {
        budgets.reduce(0) { $0 + $1.monthlyLimit }
    }
    
    private var totalSpent: Double {
        budgets.reduce(0) { $0 + currentMonthSpending(for: $1.category) }
    }
    
    private func currentMonthSpending(for category: ExpenseCategory) -> Double {
        let now = Date()
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: now)!.start
        return items
            .filter { $0.category == category && $0.date >= startOfMonth }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func deleteBudgets(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(budgets[index])
        }
        try? modelContext.save()
        deleteTrigger.toggle()
    }
}

// MARK: - Budget Row

struct BudgetRow: View {
    let budget: Budget
    let spending: Double
    
    var progress: Double {
        guard budget.monthlyLimit > 0 else { return 0 }
        return min(spending / budget.monthlyLimit, 1.0)
    }
    
    var isOverBudget: Bool {
        spending > budget.monthlyLimit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(budget.category.displayName)
                    .font(.headline)
                Spacer()
                Text("₹\(String(format: "%.0f", spending)) / ₹\(String(format: "%.0f", budget.monthlyLimit))")
                    .font(.subheadline)
                    .foregroundStyle(isOverBudget ? .red : .secondary)
            }
            
            ProgressView(value: progress)
                .tint(isOverBudget ? .red : (progress > 0.8 ? .orange : .blue))
            
            if isOverBudget {
                Text("Over budget by ₹\(String(format: "%.0f", spending - budget.monthlyLimit))")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("₹\(String(format: "%.0f", budget.monthlyLimit - spending)) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Budget Sheet

struct AddBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var budgets: [Budget]
    
    @State private var selectedCategory: ExpenseCategory = .food
    @State private var monthlyLimit = ""
    @State private var showAlert = false
    @State private var saveTrigger = false
    
    var availableCategories: [ExpenseCategory] {
        let existingCategories = Set(budgets.map { $0.category })
        return ExpenseCategory.allCases.filter { !existingCategories.contains($0) }
    }
    
    var body: some View {
        NavigationView {
            Form {
                SwiftUI.Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(availableCategories) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }
                
                SwiftUI.Section("Monthly Limit") {
                    TextField("Amount in ₹", text: $monthlyLimit)
                        .keyboardType(.decimalPad)
                }
                
                SwiftUI.Section {
                    Text("Set a monthly spending limit for **\(selectedCategory.displayName)**. You'll see progress and alerts when approaching or exceeding the budget.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let limit = Double(monthlyLimit), limit > 0 else {
                            showAlert = true
                            return
                        }
                        let budget = Budget(category: selectedCategory, monthlyLimit: limit)
                        modelContext.insert(budget)
                        try? modelContext.save()
                        SetBudgetTip.hasBudget = true
                        saveTrigger.toggle()
                        dismiss()
                    }
                }
            }
            .alert("Invalid Amount", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter a valid budget amount greater than 0.")
            }
            .onAppear {
                if let first = availableCategories.first {
                    selectedCategory = first
                }
            }
            .sensoryFeedback(.success, trigger: saveTrigger)
        }
    }
}

#Preview {
    BudgetView()
        .modelContainer(for: [Budget.self, Item.self], inMemory: true)
}
