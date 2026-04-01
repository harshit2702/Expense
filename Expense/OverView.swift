//
//  OverView.swift
//  Expense
//
//  Created by Harshit Agarwal on 25/09/24.
//

import SwiftUI
import SwiftData
import Charts
import TipKit

struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.analyticsFilterOptions) private var analyticsFilters
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    @Query private var budgets: [Budget]
    @Query private var monthlyBudgetSettings: [MonthlyBudgetSettings]
    private let overviewTip = OverviewTip()

    @State private var selectedCategoryAmount: Double?
    @State private var selectedCategory: String = ""
    @State private var selectedPrice: Double = 0.0
    @State private var dateRangeType: DateRangeType = .last30Days
    @State private var startDate = Date()
    @State private var endDate = Date()

    enum DateRangeType: String, CaseIterable, Identifiable {
        case last7Days = "7 Days"
        case last14Days = "14 Days"
        case last30Days = "30 Days"
        case custom = "Custom"
        var id: String { self.rawValue }
    }

    // MARK: - Computed Data

    private var itemsAfterInspectorFilters: [Item] {
        items.filter { item in
            let categoryMatches = analyticsFilters.category == nil || item.category == analyticsFilters.category
            let methodMatches = analyticsFilters.paymentMethod == nil || item.paymentMethod == analyticsFilters.paymentMethod
            return categoryMatches && methodMatches
        }
    }

    private var filteredItems: [Item] {
        itemsAfterInspectorFilters.filter { $0.date >= startDate && $0.date <= endDate }
    }

    private var totalSpent: Double { filteredItems.reduce(0) { $0 + $1.amount } }

    private var categoryAmount: [(category: ExpenseCategory, amount: Double, cumulativeAmountSt: Double, cumulativeAmountEnd: Double)] {
        let amountDict = filteredItems.reduce(into: [ExpenseCategory: Double]()) { $0[$1.category, default: 0] += $1.amount }
        let sorted = amountDict.sorted { $0.value > $1.value }.map { $0.key }
        var cum: Double = 0
        return sorted.map { cat in
            let amt = amountDict[cat]!
            cum += amt
            return (cat, amt, cum - amt, cum)
        }
    }

    // Previous period for comparison
    private var previousPeriodTotal: Double {
        let duration = endDate.timeIntervalSince(startDate)
        let prevStart = startDate.addingTimeInterval(-duration)
        let prevEnd = startDate
        return itemsAfterInspectorFilters.filter { $0.date >= prevStart && $0.date < prevEnd }.reduce(0) { $0 + $1.amount }
    }

    private var periodChange: Double {
        guard previousPeriodTotal > 0 else { return 0 }
        return ((totalSpent - previousPeriodTotal) / previousPeriodTotal) * 100
    }

    // Top overspending category vs budget
    private var topOverspender: (category: String, overBy: Double)? {
        let spendByCategory = ExpenseDataManager.monthSpendByCategory(from: itemsAfterInspectorFilters)
        return budgets
            .compactMap { budget -> (category: String, overBy: Double)? in
                let spent = spendByCategory[budget.category] ?? 0
                guard spent > budget.monthlyLimit else { return nil }
                return (budget.category.displayName, spent - budget.monthlyLimit)
            }
            .max(by: { $0.overBy < $1.overBy })
    }

    // Budget risk this month
    private var budgetUsedPercent: Double {
        let configuredTotal = monthlyBudgetSettings.first?.monthlyTotalBudget
        if let configuredTotal, configuredTotal > 0 {
            return ExpenseDataManager.monthlyBudgetUsagePercent(
                monthlyTotalBudget: configuredTotal,
                items: itemsAfterInspectorFilters
            )
        }

        let categoryLimitTotal = ExpenseDataManager.categoryBudgetTotal(from: budgets)
        guard categoryLimitTotal > 0 else { return 0 }
        let monthSpent = ExpenseDataManager.monthSpend(from: itemsAfterInspectorFilters)
        return (monthSpent / categoryLimitTotal) * 100
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TipView(overviewTip)
                    .padding(.horizontal)

                // Period Picker
                Picker("Period", selection: $dateRangeType) {
                    ForEach(DateRangeType.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: dateRangeType) { _, _ in updateDateRange() }

                if dateRangeType == .custom {
                    HStack {
                        DatePicker("From", selection: $startDate, displayedComponents: .date)
                        DatePicker("To", selection: $endDate, displayedComponents: .date)
                    }
                    .padding(.horizontal)
                }

                // MARK: Summary Cards (3 decisions)
                VStack(spacing: 12) {
                    // Total + change
                    HStack(spacing: 12) {
                        SummaryCard(title: "Period Total", amount: totalSpent, color: .blue)
                        SummaryCard(title: "vs Previous", amount: periodChange, color: periodChange > 0 ? .red : .green, isPercent: true)
                    }

                    HStack(spacing: 12) {
                        // Budget risk
                        VStack(spacing: 4) {
                            Text("Budget Used")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if budgets.isEmpty && monthlyBudgetSettings.first?.monthlyTotalBudget == nil {
                                Text("—")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(String(format: "%.0f", budgetUsedPercent))%")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(budgetUsedPercent > 100 ? .red : budgetUsedPercent > 80 ? .orange : .green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Top overspender
                        VStack(spacing: 4) {
                            Text("Top Overspend")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let over = topOverspender {
                                Text(over.category)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("+₹\(String(format: "%.0f", over.overBy))")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text("None")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)

                // MARK: Ring Chart
                if !categoryAmount.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category Breakdown")
                            .font(.headline)

                        if !selectedCategory.isEmpty {
                            HStack {
                                Text(selectedCategory)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("₹\(String(format: "%.0f", selectedPrice))")
                                    .fontWeight(.bold)
                            }
                            .font(.subheadline)
                            .padding(8)
                            .background(.blue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Chart(categoryAmount, id: \.category) { entry in
                            SectorMark(
                                angle: .value("Category", entry.amount),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("Category", entry.category.displayName))
                            .cornerRadius(4)
                        }
                        .chartAngleSelection(value: $selectedCategoryAmount)
                        .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
                        .frame(height: 220)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }

                // MARK: Insight Cards
                VStack(spacing: 10) {
                    if let top = categoryAmount.first {
                        let pct = totalSpent > 0 ? (top.amount / totalSpent * 100) : 0
                        InsightRow(icon: "flame.fill", color: .orange,
                                   text: "\(top.category.displayName) is \(String(format: "%.0f", pct))% of spending",
                                   detail: "₹\(String(format: "%.0f", top.amount)) in this period")
                    }
                    if periodChange != 0 {
                        let dir = periodChange > 0 ? "more" : "less"
                        InsightRow(icon: periodChange > 0 ? "arrow.up.right" : "arrow.down.right",
                                   color: periodChange > 0 ? .red : .green,
                                   text: "\(String(format: "%.0f", abs(periodChange)))% \(dir) than previous period",
                                   detail: "Previous: ₹\(String(format: "%.0f", previousPeriodTotal))")
                    }
                    if budgetUsedPercent > 80 && !budgets.isEmpty {
                        InsightRow(icon: "exclamationmark.triangle.fill", color: .orange,
                                   text: "Budget \(String(format: "%.0f", budgetUsedPercent))% used",
                                   detail: "Consider reducing discretionary spending")
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // MARK: Historical Charts
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spending Over Time")
                        .font(.headline)
                    ChartView(categories: ExpenseCategory.allCases)
                        .frame(height: 250)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .onAppear { updateDateRange() }
        .onChange(of: selectedCategoryAmount) { _, newValue in
            if let selectedAmount = newValue {
                if let entry = categoryAmount.first(where: { $0.cumulativeAmountSt <= selectedAmount && selectedAmount < $0.cumulativeAmountEnd }) {
                    selectedCategory = entry.category.displayName
                    selectedPrice = entry.amount
                } else {
                    selectedCategory = ""
                    selectedPrice = 0.0
                }
            }
        }
    }

    // MARK: - Helpers

    private func updateDateRange() {
        let calendar = Calendar.current
        switch dateRangeType {
        case .last7Days:
            startDate = calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date()
            endDate = Date()
        case .last14Days:
            startDate = calendar.date(byAdding: .day, value: -13, to: Date()) ?? Date()
            endDate = Date()
        case .last30Days:
            startDate = calendar.date(byAdding: .day, value: -29, to: Date()) ?? Date()
            endDate = Date()
        case .custom:
            break
        }
    }
}

#Preview {
    OverviewView()
}
