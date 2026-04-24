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
    @State private var selectedPaymentAmount: Double?
    @State private var selectedPaymentLabel: String = ""
    @State private var selectedPaymentPrice: Double = 0
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
        let sorted = amountDict.sorted { $0.value > $1.value }
        var cum: Double = 0
        return sorted.map { cat, amt in
            cum += amt
            return (cat, amt, cum - amt, cum)
        }
    }

    private var paymentMethodAmount: [(method: String, amount: Double, cumulativeAmountSt: Double, cumulativeAmountEnd: Double)] {
        let amountDict = filteredItems.reduce(into: [String: Double]()) { result, item in
            let methodName = item.paymentMethod?.displayName ?? "Not Set"
            result[methodName, default: 0] += item.amount
        }
        let sorted = amountDict.sorted { $0.value > $1.value }
        var cumulative = 0.0
        return sorted.map { entry in
            let start = cumulative
            cumulative += entry.value
            return (entry.key, entry.value, start, cumulative)
        }
    }

    private var creditCardSpend: Double {
        filteredItems
            .filter { $0.paymentMethod == .creditCard && $0.transactionType == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private var creditCardBillPayment: Double {
        filteredItems
            .filter { $0.transactionType == .creditCardBillPayment }
            .reduce(0) { $0 + $1.amount }
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
                DateRangeSelector(
                    selection: $dateRangeType,
                    startDate: $startDate,
                    endDate: $endDate,
                    customOption: .custom,
                    onSelectionChanged: updateDateRange
                )
                .padding(.horizontal)

                if filteredItems.isEmpty {
                    CardSurface {
                        ContentUnavailableView(
                            "No Data",
                            systemImage: "chart.pie",
                            description: Text("No expenses found in the selected period.")
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                } else {
                    // MARK: Summary Cards (3 decisions)
                    VStack(spacing: 12) {
                        // Total + change
                        HStack(spacing: 12) {
                            MetricCard(
                                title: "Period Total",
                                value: "₹\(String(format: "%.0f", totalSpent))",
                                valueColor: .blue,
                                overlayTint: .blue
                            )
                            MetricCard(
                                title: "vs Previous",
                                value: "\(periodChange >= 0 ? "+" : "")\(String(format: "%.1f", periodChange))%",
                                valueColor: periodChange > 0 ? .red : .green,
                                overlayTint: periodChange > 0 ? .red : .green
                            )
                        }

                        HStack(spacing: 12) {
                            MetricCard(
                                title: "Budget Used",
                                value: budgets.isEmpty && monthlyBudgetSettings.first?.monthlyTotalBudget == nil
                                    ? "—"
                                    : "\(String(format: "%.0f", budgetUsedPercent))%",
                                valueColor: budgetUsedPercent > 100 ? .red : budgetUsedPercent > 80 ? .orange : .green,
                                overlayTint: budgetUsedPercent > 100 ? .red : budgetUsedPercent > 80 ? .orange : .green
                            )

                            MetricCard(
                                title: "Top Overspend",
                                value: topOverspender?.category ?? "None",
                                valueColor: topOverspender == nil ? .green : .primary,
                                valueFont: .subheadline,
                                overlayTint: topOverspender == nil ? .green : .red
                            ) {
                                if let over = topOverspender {
                                    Text("+₹\(String(format: "%.0f", over.overBy))")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // MARK: Ring Chart
                    if !categoryAmount.isEmpty {
                        ChartContainer(title: "Category Breakdown") {
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
                                .transition(.opacity.combined(with: .move(edge: .top)))
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
                            .accessibilityLabel("Category breakdown chart")
                            .accessibilityValue("\(categoryAmount.count) categories")
                        }
                        .padding(.horizontal)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedCategory)
                    }

                    if !paymentMethodAmount.isEmpty {
                        ChartContainer(title: "Payment Method Breakdown") {
                            if !selectedPaymentLabel.isEmpty {
                                HStack {
                                    Text(selectedPaymentLabel)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("₹\(String(format: "%.0f", selectedPaymentPrice))")
                                        .fontWeight(.bold)
                                }
                                .font(.subheadline)
                                .padding(8)
                                .background(.blue.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            Chart(paymentMethodAmount, id: \.method) { entry in
                                SectorMark(
                                    angle: .value("Payment Method", entry.amount),
                                    innerRadius: .ratio(0.62),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(by: .value("Payment Method", entry.method))
                                .cornerRadius(4)
                            }
                            .chartAngleSelection(value: $selectedPaymentAmount)
                            .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
                            .frame(height: 220)
                            .accessibilityLabel("Payment method breakdown chart")
                            .accessibilityValue("\(paymentMethodAmount.count) payment methods")
                        }
                        .padding(.horizontal)
                    }

                    CardSurface {
                        VStack(spacing: 10) {
                            InsightRow(
                                icon: "creditcard.fill",
                                color: .blue,
                                text: "Credit card spend: ₹\(String(format: "%.0f", creditCardSpend))",
                                detail: "Card bill paid: ₹\(String(format: "%.0f", creditCardBillPayment))"
                            )

                            let delta = creditCardSpend - creditCardBillPayment
                            InsightRow(
                                icon: delta > 0 ? "arrow.up.right.square.fill" : "arrow.down.right.square.fill",
                                color: delta > 0 ? .orange : .green,
                                text: delta > 0 ? "Unsettled card usage trend" : "Card dues being settled",
                                detail: "\(delta >= 0 ? "+" : "-")₹\(String(format: "%.0f", abs(delta))) vs bill payments"
                            )
                        }
                    }
                    .padding(.horizontal)

                    // MARK: Insight Cards
                    CardSurface {
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
                    }
                    .padding(.horizontal)

                    // MARK: Historical Charts
                    ChartContainer(title: "Spending Over Time") {
                        ChartView(categories: ExpenseCategory.allCases)
                            .frame(height: 250)
                            .accessibilityLabel("Spending over time chart")
                            .accessibilityValue("Interactive chart with week, month, and year ranges")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, 8)
        }
        .onAppear {
            updateDateRange()
            OverviewTip.hasViewedOverview = true
        }
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
        .onChange(of: selectedPaymentAmount) { _, newValue in
            if let selectedAmount = newValue {
                if let entry = paymentMethodAmount.first(where: { $0.cumulativeAmountSt <= selectedAmount && selectedAmount < $0.cumulativeAmountEnd }) {
                    selectedPaymentLabel = entry.method
                    selectedPaymentPrice = entry.amount
                } else {
                    selectedPaymentLabel = ""
                    selectedPaymentPrice = 0
                }
            }
        }
        .onChange(of: startDate) { _, newValue in
            if newValue > endDate {
                endDate = newValue
            }
        }
        .onChange(of: endDate) { _, newValue in
            if newValue < startDate {
                startDate = newValue
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
