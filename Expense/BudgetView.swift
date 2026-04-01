//
//  BudgetView.swift
//  Expense
//
//  Created by Harshit Agarwal on 01/03/26.
//

import SwiftUI
import SwiftData
import Charts
import TipKit

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @Query private var monthlyBudgetSettings: [MonthlyBudgetSettings]
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    @State private var showAddBudget = false
    @State private var showMonthlyBudgetSheet = false
    @State private var monthlyBudgetInput = ""
    @State private var showMonthlyBudgetAlert = false
    @State private var deleteTrigger = false
    @State private var rebalanceTrigger = false
    private let budgetTip = SetBudgetTip()
    
    var body: some View {
        List {
            TipView(budgetTip)

            SwiftUI.Section("Total Monthly Budget") {
                HStack(spacing: 12) {
                    MetricChip(
                        title: "Configured",
                        value: monthlySettings.monthlyTotalBudget.map { "₹\(String(format: "%.0f", $0))" } ?? "Not set",
                        tone: .blue
                    )
                    MetricChip(
                        title: "Spent",
                        value: "₹\(String(format: "%.0f", monthSpentOverall))",
                        tone: .orange
                    )
                    MetricChip(
                        title: "Remaining",
                        value: monthlyRemainingText,
                        tone: monthRemainingValue.map { $0 < 0 ? .red : .green } ?? .secondary
                    )
                }
                .frame(maxWidth: .infinity)

                Button("Set Monthly Total") {
                    monthlyBudgetInput = monthlySettings.monthlyTotalBudget.map { String(format: "%.0f", $0) } ?? ""
                    showMonthlyBudgetSheet = true
                }

                Text("Set a monthly total to unlock full budget health tracking and pacing guidance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if budgets.isEmpty {
                ContentUnavailableView(
                    "No Budgets Set",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("Tap + to add a monthly budget for any category.")
                )
            } else {
                // Summary Section
                SwiftUI.Section("Category Budget Summary") {
                    HStack {
                        Text("Total Category Budgets")
                        Spacer()
                        Text("₹\(String(format: "%.0f", totalBudget))")
                            .fontWeight(.bold)
                    }
                    HStack {
                        Text("Spent in Budgeted Categories")
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

                    if !allocationChartData.isEmpty {
                        Chart(allocationChartData) { entry in
                            BarMark(
                                x: .value("Category", entry.category),
                                y: .value("Amount", entry.amount)
                            )
                            .position(by: .value("Type", entry.type))
                            .foregroundStyle(by: .value("Type", entry.type))
                        }
                        .chartLegend(position: .bottom)
                        .frame(height: 220)
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

                // MARK: Smart Coaching Nudges
                SwiftUI.Section("Coaching") {
                    ForEach(coachingNudges, id: \.text) { nudge in
                        InsightRow(icon: nudge.icon, color: nudge.color, text: nudge.text, detail: nudge.detail)
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
        .sheet(isPresented: $showMonthlyBudgetSheet) {
            MonthlyBudgetSheet(
                monthlyTotalBudgetInput: $monthlyBudgetInput,
                onSave: {
                    saveMonthlyTotalBudget()
                    showMonthlyBudgetSheet = false
                },
                onCancel: {
                    showMonthlyBudgetSheet = false
                }
            )
        }
        .onAppear {
            ensureMonthlySettingsExists()
        }
        .alert("Invalid Monthly Total", isPresented: $showMonthlyBudgetAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Enter a valid amount greater than 0. Leave empty only if you want to clear the total budget.")
        }
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.5), trigger: deleteTrigger)
        .sensoryFeedback(.success, trigger: rebalanceTrigger)
    }

    private var monthlySettings: MonthlyBudgetSettings {
        if let existing = monthlyBudgetSettings.first { return existing }
        let created = MonthlyBudgetSettings()
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }

    private func ensureMonthlySettingsExists() {
        _ = monthlySettings
    }

    private func saveMonthlyTotalBudget() {
        let trimmed = monthlyBudgetInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            monthlySettings.monthlyTotalBudget = nil
            monthlySettings.updatedAt = Date()
            try? modelContext.save()
            return
        }

        guard let value = Double(trimmed), value > 0 else {
            showMonthlyBudgetAlert = true
            return
        }

        monthlySettings.monthlyTotalBudget = value
        monthlySettings.updatedAt = Date()
        try? modelContext.save()
    }
    
    private var totalBudget: Double {
        ExpenseDataManager.categoryBudgetTotal(from: budgets)
    }
    
    private var totalSpent: Double {
        ExpenseDataManager.budgetedCategorySpend(from: items, budgets: budgets)
    }

    private var monthSpentOverall: Double {
        ExpenseDataManager.monthSpend(from: items)
    }

    private var currentMonthSpendByCategory: [ExpenseCategory: Double] {
        ExpenseDataManager.monthSpendByCategory(from: items)
    }

    private var monthRemainingValue: Double? {
        guard let monthlyTotalBudget = monthlySettings.monthlyTotalBudget else { return nil }
        return monthlyTotalBudget - monthSpentOverall
    }

    private var monthlyRemainingText: String {
        guard let remaining = monthRemainingValue else { return "—" }
        return "₹\(String(format: "%.0f", remaining))"
    }
    
    private func currentMonthSpending(for category: ExpenseCategory) -> Double {
        currentMonthSpendByCategory[category] ?? 0
    }

    private func gapMessage(for gap: Double) -> String {
        if abs(gap) < 0.5 { return "Category limits exactly match your monthly total." }
        if gap > 0 {
            return "₹\(String(format: "%.0f", gap)) is unallocated across categories."
        }
        return "Category limits exceed monthly total by ₹\(String(format: "%.0f", abs(gap)))."
    }
    
    private func deleteBudgets(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(budgets[index])
        }
        try? modelContext.save()
        deleteTrigger.toggle()
    }

    private func rebalanceCategoryBudgets(to targetTotal: Double) {
        guard !budgets.isEmpty, targetTotal > 0 else { return }

        let currentTotal = totalBudget
        if currentTotal <= 0 {
            let evenLimit = targetTotal / Double(budgets.count)
            for budget in budgets {
                budget.monthlyLimit = evenLimit
            }
        } else {
            let ratio = targetTotal / currentTotal
            for budget in budgets {
                budget.monthlyLimit *= ratio
            }
        }

        try? modelContext.save()
        rebalanceTrigger.toggle()
    }

    // MARK: - Coaching Nudges

    private var coachingNudges: [(icon: String, color: Color, text: String, detail: String)] {
        var nudges: [(icon: String, color: Color, text: String, detail: String)] = []
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayOfMonth = cal.component(.day, from: today)
        let daysInMonth = cal.range(of: .day, in: .month, for: today)?.count ?? 30
        let daysLeft = max(daysInMonth - dayOfMonth, 1)
        let fractionElapsed = Double(dayOfMonth) / Double(daysInMonth)

        for budget in budgets {
            let spent = currentMonthSpending(for: budget.category)
            let usedPct = budget.monthlyLimit > 0 ? spent / budget.monthlyLimit : 0
            let remaining = budget.monthlyLimit - spent

            if usedPct > 1.0 {
                // Already over — suggest recovery
                nudges.append((
                    icon: "exclamationmark.triangle.fill", color: .red,
                    text: "\(budget.category.displayName) over by ₹\(String(format: "%.0f", -remaining))",
                    detail: "Avoid further spending in this category"
                ))
            } else if usedPct > fractionElapsed + 0.15 {
                // Spending faster than expected
                let dailyBudget = remaining / Double(daysLeft)
                nudges.append((
                    icon: "gauge.with.dots.needle.67percent", color: .orange,
                    text: "\(budget.category.displayName) at \(String(format: "%.0f", usedPct * 100))% with \(daysLeft) days left",
                    detail: "Limit to ₹\(String(format: "%.0f", dailyBudget))/day to stay on track"
                ))
            } else if usedPct < fractionElapsed * 0.5 && spent > 0 {
                // Under budget — positive reinforcement
                nudges.append((
                    icon: "hand.thumbsup.fill", color: .green,
                    text: "\(budget.category.displayName) well under budget",
                    detail: "₹\(String(format: "%.0f", remaining)) remaining — great job!"
                ))
            }
        }

        if nudges.isEmpty && !budgets.isEmpty {
            nudges.append((
                icon: "checkmark.seal.fill", color: .green,
                text: "All budgets on track",
                detail: "Keep it up! You're spending responsibly."
            ))
        }

        return nudges
    }

    private var allocationChartData: [BudgetAllocationDatum] {
        budgets.flatMap { budget in
            [
                BudgetAllocationDatum(category: budget.category.displayName, type: "Limit", amount: budget.monthlyLimit),
                BudgetAllocationDatum(category: budget.category.displayName, type: "Spent", amount: currentMonthSpending(for: budget.category))
            ]
        }
    }
}

private struct BudgetAllocationDatum: Identifiable {
    let id = UUID()
    let category: String
    let type: String
    let amount: Double
}

private struct MetricChip: View {
    let title: String
    let value: String
    let tone: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(tone)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Budget Row

struct BudgetRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var budget: Budget
    let spending: Double
    @State private var isEditingLimit = false
    @State private var limitInput = ""
    @State private var showInvalidLimitAlert = false
    @State private var saveTrigger = false
    
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
                if isEditingLimit {
                    TextField("Limit", text: $limitInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)

                    Button("Save") {
                        saveEditedLimit()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)

                    Button("Cancel") {
                        cancelEditing()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                } else {
                    Text("₹\(String(format: "%.0f", spending)) / ₹\(String(format: "%.0f", budget.monthlyLimit))")
                        .font(.subheadline)
                        .foregroundStyle(isOverBudget ? .red : .secondary)

                    Button {
                        startEditing()
                    } label: {
                        Image(systemName: "pencil.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
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
        .alert("Invalid Limit", isPresented: $showInvalidLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Enter a valid amount greater than 0.")
        }
        .sensoryFeedback(.success, trigger: saveTrigger)
        .onAppear {
            limitInput = String(format: "%.0f", budget.monthlyLimit)
        }
    }

    private func startEditing() {
        limitInput = String(format: "%.0f", budget.monthlyLimit)
        isEditingLimit = true
    }

    private func cancelEditing() {
        limitInput = String(format: "%.0f", budget.monthlyLimit)
        isEditingLimit = false
    }

    private func saveEditedLimit() {
        let trimmed = limitInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else {
            showInvalidLimitAlert = true
            return
        }

        budget.monthlyLimit = value
        try? modelContext.save()
        saveTrigger.toggle()
        isEditingLimit = false
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
        return ExpenseCategory.primaryCases.filter { !existingCategories.contains($0) }
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

// MARK: - Monthly Budget Sheet

struct MonthlyBudgetSheet: View {
    @Binding var monthlyTotalBudgetInput: String
    var onSave: () -> Void
    var onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                SwiftUI.Section("Monthly Total Budget") {
                    TextField("Amount in ₹", text: $monthlyTotalBudgetInput)
                        .keyboardType(.decimalPad)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                SwiftUI.Section {
                    Text("Enter your total monthly budget amount. This will help track your overall spending and remaining budget for the month.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Set Monthly Total")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
            .alert("Invalid Amount", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter a valid budget amount greater than 0.")
            }
        }
    }
}

#Preview {
    BudgetView()
    .modelContainer(for: [Budget.self, Item.self, MonthlyBudgetSettings.self], inMemory: true)
}
