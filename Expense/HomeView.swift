//
//  HomeView.swift
//  Expense
//
//  Beautiful iPhone-first home dashboard.
//  Hero summary → ring chart → 7-day bar → insight strip → quick actions.
//

import SwiftUI
import SwiftData
import Charts
import TipKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    @Query private var budgets: [Budget]
    @Query private var monthlyBudgetSettings: [MonthlyBudgetSettings]
    @State private var isAddPresented = false
    private let addExpenseTip = AddExpenseTip()

    // MARK: Computed Data

    private var currentMonthItems: [Item] {
        ExpenseDataManager.currentMonthItems(from: items)
    }

    private var lastMonthItems: [Item] {
        let cal = Calendar.current
        let startOfThisMonth = cal.dateInterval(of: .month, for: Date())!.start
        let startOfLastMonth = cal.date(byAdding: .month, value: -1, to: startOfThisMonth)!
        return items.filter { $0.date >= startOfLastMonth && $0.date < startOfThisMonth }
    }

    private var thisMonthTotal: Double { currentMonthItems.reduce(0) { $0 + $1.amount } }
    private var lastMonthTotal: Double { lastMonthItems.reduce(0) { $0 + $1.amount } }

    private var monthOverMonthChange: Double {
        guard lastMonthTotal > 0 else { return 0 }
        return ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100
    }

    private var monthlyTotalBudget: Double? { monthlyBudgetSettings.first?.monthlyTotalBudget }
    private var budgetRemaining: Double? {
        guard let monthlyTotalBudget else { return nil }
        return monthlyTotalBudget - ExpenseDataManager.monthSpend(from: items)
    }

    private var categoryBreakdown: [(category: ExpenseCategory, amount: Double)] {
        let dict = currentMonthItems.reduce(into: [ExpenseCategory: Double]()) { $0[$1.category, default: 0] += $1.amount }
        return dict.sorted { $0.value > $1.value }.map { (category: $0.key, amount: $0.value) }
    }

    private var last7DaysTotals: [(date: Date, amount: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sevenDaysAgo = cal.date(byAdding: .day, value: -6, to: today)!
        let recent = items.filter { $0.date >= sevenDaysAgo }
        let grouped = Dictionary(grouping: recent) { cal.startOfDay(for: $0.date) }

        return (0..<7).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: sevenDaysAgo)!
            let amount = grouped[day]?.reduce(0) { $0 + $1.amount } ?? 0
            return (date: day, amount: amount)
        }
    }

    private var todayTotal: Double {
        let start = Calendar.current.startOfDay(for: Date())
        return items.filter { $0.date >= start }.reduce(0) { $0 + $1.amount }
    }

    // Insights
    private var topCategory: (name: String, amount: Double)? {
        guard let top = categoryBreakdown.first else { return nil }
        return (name: top.category.displayName, amount: top.amount)
    }

    private var highestSpendDay: (date: Date, amount: Double)? {
        last7DaysTotals.max(by: { $0.amount < $1.amount })
    }

    private var budgetRiskLevel: String {
        guard let monthlyTotalBudget, monthlyTotalBudget > 0 else { return "Monthly total not set" }
        let used = ExpenseDataManager.monthlyBudgetUsagePercent(monthlyTotalBudget: monthlyTotalBudget, items: items) / 100
        if used > 1.0 { return "Over budget" }
        if used > 0.8 { return "At risk" }
        return "On track"
    }

    private var budgetRiskColor: Color {
        guard let monthlyTotalBudget, monthlyTotalBudget > 0 else { return .secondary }
        let used = ExpenseDataManager.monthlyBudgetUsagePercent(monthlyTotalBudget: monthlyTotalBudget, items: items) / 100
        if used > 1.0 { return .red }
        if used > 0.8 { return .orange }
        return .green
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: Hero Summary Card
                heroSummary
                    .padding(.horizontal)

                // MARK: Ring Chart — Category Split
                if !categoryBreakdown.isEmpty {
                    ringChartCard
                        .padding(.horizontal)
                }

                // MARK: 7-Day Spending Bar
                weekBarCard
                    .padding(.horizontal)

                // MARK: Insight Strip
                insightStrip
                    .padding(.horizontal)

                // MARK: Quick Actions
                quickActions
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { isAddPresented = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .popoverTip(addExpenseTip, arrowEdge: .top)
            }
        }
        .sheet(isPresented: $isAddPresented) {
            AddView(isPresented: $isAddPresented)
        }
    }

    // MARK: - Components

    private var heroSummary: some View {
        VStack(spacing: 16) {
            // Today
            VStack(spacing: 4) {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("₹\(String(format: "%.0f", todayTotal))")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Divider()

            HStack(spacing: 0) {
                // This Month
                VStack(spacing: 4) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("₹\(String(format: "%.0f", thisMonthTotal))")
                        .font(.title3)
                        .fontWeight(.bold)
                    HStack(spacing: 2) {
                        Image(systemName: monthOverMonthChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text("\(String(format: "%.1f", abs(monthOverMonthChange)))%")
                            .font(.caption2)
                    }
                    .foregroundStyle(monthOverMonthChange > 0 ? .red : .green)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                // Budget Remaining
                VStack(spacing: 4) {
                    Text("Budget Left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let budgetRemaining {
                        Text("₹\(String(format: "%.0f", budgetRemaining))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(budgetRemaining < 0 ? .red : .primary)
                        Text(budgetRiskLevel)
                            .font(.caption2)
                            .foregroundStyle(budgetRiskColor)
                    } else {
                        Text("—")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Set monthly total in Budget")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var ringChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)

            Chart(categoryBreakdown.prefix(8), id: \.category) { entry in
                SectorMark(
                    angle: .value("Amount", entry.amount),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Category", entry.category.displayName))
                .cornerRadius(4)
            }
            .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
            .frame(height: 200)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var weekBarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.headline)

            Chart(last7DaysTotals, id: \.date) { entry in
                BarMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Amount", entry.amount)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) {
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("₹\(String(format: "%.0f", v))")
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 160)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var insightStrip: some View {
        VStack(spacing: 10) {
            if let top = topCategory {
                InsightRow(icon: "flame.fill", color: .orange,
                           text: "Top: \(top.name)",
                           detail: "₹\(String(format: "%.0f", top.amount)) this month")
            }
            if let peak = highestSpendDay, peak.amount > 0 {
                InsightRow(icon: "arrow.up.circle.fill", color: .red,
                           text: "Peak day: \(peak.date.formatted(.dateTime.weekday(.wide)))",
                           detail: "₹\(String(format: "%.0f", peak.amount))")
            }
            // Budget coaching nudge
            if let budgetRemaining {
                let daysLeft = daysRemainingInMonth()
                let dailyBudget = daysLeft > 0 ? budgetRemaining / Double(daysLeft) : 0
                if budgetRemaining > 0 {
                    InsightRow(icon: "lightbulb.fill", color: .yellow,
                               text: "Daily budget left: ₹\(String(format: "%.0f", dailyBudget))",
                               detail: "\(daysLeft) days remaining")
                } else {
                    InsightRow(icon: "exclamationmark.triangle.fill", color: .red,
                               text: "Over budget by ₹\(String(format: "%.0f", abs(budgetRemaining)))",
                               detail: "Reduce spending to recover")
                }
            } else {
                InsightRow(icon: "info.circle.fill", color: .secondary,
                           text: "Monthly total budget not set",
                           detail: "Set it in Budget tab to track Budget Left")
            }
            // Month-over-month
            if lastMonthTotal > 0 {
                let direction = monthOverMonthChange >= 0 ? "more" : "less"
                InsightRow(icon: monthOverMonthChange >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                           color: monthOverMonthChange >= 0 ? .red : .green,
                           text: "\(String(format: "%.0f", abs(monthOverMonthChange)))% \(direction) than last month",
                           detail: "Last month: ₹\(String(format: "%.0f", lastMonthTotal))")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionButton(icon: "plus.circle.fill", label: "Add Expense", color: .blue) {
                isAddPresented = true
            }
            NavigationLink {
                EntryListView()
            } label: {
                QuickActionLabel(icon: "list.bullet.rectangle.fill", label: "All Entries", color: .indigo)
            }
            NavigationLink {
                BudgetView()
                    .navigationTitle("Budget")
            } label: {
                QuickActionLabel(icon: "target", label: "Budgets", color: .green)
            }
        }
    }

    // MARK: Helpers

    private func daysRemainingInMonth() -> Int {
        ExpenseDataManager.daysRemainingInMonth()
    }
}

// MARK: - Reusable Sub-Views

struct InsightRow: View {
    let icon: String
    let color: Color
    let text: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct QuickActionLabel: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: [Item.self, Budget.self, MonthlyBudgetSettings.self], inMemory: true)
}
