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
    @State private var selectedWeekDate: Date?
    private let addExpenseTip = AddExpenseTip()

    // MARK: Computed Data

    private var currentMonthItems: [Item] {
        ExpenseDataManager.currentMonthItems(from: items)
    }

    private var lastMonthItems: [Item] {
        let cal = Calendar.current
        let startOfThisMonth = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
        let startOfLastMonth = cal.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? startOfThisMonth
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
        let sevenDaysAgo = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let recent = items.filter { $0.date >= sevenDaysAgo }
        let grouped = Dictionary(grouping: recent) { cal.startOfDay(for: $0.date) }

        return (0..<7).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: sevenDaysAgo) ?? sevenDaysAgo
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

    private var selectedWeekDayAmount: Double? {
        guard let selectedWeekDate else { return nil }
        return last7DaysTotals.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedWeekDate) })?.amount
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

                if items.isEmpty {
                    emptyHomeState
                        .padding(.horizontal)
                } else {
                    // MARK: Hero Summary Card
                    heroSummary
                        .padding(.horizontal)

                    // MARK: Ring Chart — Category Split
                    if !categoryBreakdown.isEmpty {
                        ringChartCard
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }

                    // MARK: 7-Day Spending Bar
                    weekBarCard
                        .padding(.horizontal)

                    // MARK: Insight Strip
                    insightStrip
                        .padding(.horizontal)
                }

                // MARK: Quick Actions
                quickActions
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .animation(.easeInOut(duration: 0.25), value: items.count)
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

    private var emptyHomeState: some View {
        CardSurface {
            ContentUnavailableView(
                "No Expenses Yet",
                systemImage: "wallet.bifold",
                description: Text("Add your first expense to unlock insights, charts, and budget coaching.")
            )
        }
    }

    private var heroSummary: some View {
        CardSurface {
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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Today's spending")
                .accessibilityValue("₹\(String(format: "%.0f", todayTotal))")

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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("This month spending")
                    .accessibilityValue("₹\(String(format: "%.0f", thisMonthTotal)), \(String(format: "%.1f", abs(monthOverMonthChange))) percent \(monthOverMonthChange >= 0 ? "higher" : "lower") than last month")

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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Budget remaining")
                    .accessibilityValue(
                        budgetRemaining.map { "₹\(String(format: "%.0f", $0)), \(budgetRiskLevel)" } ?? "Not configured"
                    )
                }
            }
        }
    }

    private var ringChartCard: some View {
        ChartContainer(title: "Spending by Category") {
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
            .accessibilityLabel("Category spending distribution")
            .accessibilityValue("\(categoryBreakdown.count) categories")
        }
    }

    private var weekBarCard: some View {
        ChartContainer(title: "Last 7 Days") {
            Chart(last7DaysTotals, id: \.date) { entry in
                BarMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Amount", entry.amount)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(4)

                if let selectedWeekDate, let selectedWeekDayAmount {
                    RuleMark(x: .value("Selected Day", selectedWeekDate, unit: .day))
                        .foregroundStyle(.gray.opacity(0.35))
                        .annotation(position: .top, alignment: .leading) {
                            Text("\(selectedWeekDate.formatted(.dateTime.weekday(.abbreviated)))\n₹\(String(format: "%.0f", selectedWeekDayAmount))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(6)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                }
            }
            .chartXSelection(value: $selectedWeekDate)
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
            .accessibilityLabel("Daily spending for last seven days")
            .accessibilityValue("Total ₹\(String(format: "%.0f", last7DaysTotals.reduce(0) { $0 + $1.amount }))")
        }
    }

    private var insightStrip: some View {
        CardSurface {
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
        }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionCard(icon: "plus.circle.fill", label: "Add Expense", color: .blue) {
                isAddPresented = true
            }
            NavigationLink {
                EntryListView()
            } label: {
                QuickActionCard(icon: "list.bullet.rectangle.fill", label: "All Entries", color: .indigo)
            }
            NavigationLink {
                BudgetView()
                    .navigationTitle("Budget")
            } label: {
                QuickActionCard(icon: "target", label: "Budgets", color: .green)
            }
        }
    }

    // MARK: Helpers

    private func daysRemainingInMonth() -> Int {
        ExpenseDataManager.daysRemainingInMonth()
    }
}

// MARK: - Reusable Sub-Views

struct CardSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let paddingInsets: EdgeInsets
    let overlayTint: Color?
    private let content: Content

    init(
        cornerRadius: CGFloat = 16,
        paddingInsets: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        overlayTint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.paddingInsets = paddingInsets
        self.overlayTint = overlayTint
        self.content = content()
    }

    var body: some View {
        content
            .padding(paddingInsets)
            .background(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill((overlayTint ?? .clear).opacity(colorScheme == .dark ? 0.16 : 0.08))
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.05),
                        lineWidth: 0.8
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct MetricCard<Footer: View>: View {
    let title: String
    let value: String
    let valueColor: Color
    let valueFont: Font
    let cornerRadius: CGFloat
    let overlayTint: Color?
    private let footer: Footer

    init(
        title: String,
        value: String,
        valueColor: Color = .primary,
        valueFont: Font = .title3,
        cornerRadius: CGFloat = 12,
        overlayTint: Color? = nil,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.valueFont = valueFont
        self.cornerRadius = cornerRadius
        self.overlayTint = overlayTint
        self.footer = footer()
    }

    init(
        title: String,
        value: String,
        valueColor: Color = .primary,
        valueFont: Font = .title3,
        cornerRadius: CGFloat = 12,
        overlayTint: Color? = nil
    ) where Footer == EmptyView {
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.valueFont = valueFont
        self.cornerRadius = cornerRadius
        self.overlayTint = overlayTint
        self.footer = EmptyView()
    }

    var body: some View {
        CardSurface(
            cornerRadius: cornerRadius,
            paddingInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
            overlayTint: overlayTint
        ) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(valueFont)
                    .fontWeight(.bold)
                    .foregroundStyle(valueColor)
                    .minimumScaleFactor(0.8)
                footer
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

struct ChartContainer<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                content
            }
        }
    }
}

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

struct QuickActionCard: View {
    let icon: String
    let label: String
    let color: Color
    var action: (() -> Void)? = nil

    private var content: some View {
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

    @ViewBuilder
    var body: some View {
        if let action {
            Button(action: action) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    var fillsWidth: Bool = false
    var isCapsule: Bool = false
    var cornerRadius: CGFloat = 10
    var fontWeight: Font.Weight = .medium
    let action: () -> Void

    private var base: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(fontWeight)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .padding(.horizontal, fillsWidth ? 0 : 12)
            .padding(.vertical, fillsWidth ? 10 : 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? Color.blue : Color.secondary.opacity(0.12))
    }

    var body: some View {
        Button(action: action) {
            if isCapsule {
                base
                    .clipShape(Capsule())
            } else {
                base
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct DateIntervalFields: View {
    let fromLabel: String
    let toLabel: String
    @Binding var startDate: Date
    @Binding var endDate: Date

    init(
        fromLabel: String = "From",
        toLabel: String = "To",
        startDate: Binding<Date>,
        endDate: Binding<Date>
    ) {
        self.fromLabel = fromLabel
        self.toLabel = toLabel
        _startDate = startDate
        _endDate = endDate
    }

    var body: some View {
        HStack {
            DatePicker(fromLabel, selection: $startDate, displayedComponents: .date)
            DatePicker(toLabel, selection: $endDate, displayedComponents: .date)
        }
    }
}

struct DateRangeSelector<Option: Hashable & CaseIterable & Identifiable & RawRepresentable>: View where Option.RawValue == String {
    @Binding var selection: Option
    @Binding var startDate: Date
    @Binding var endDate: Date
    let customOption: Option?
    let onSelectionChanged: () -> Void

    init(
        selection: Binding<Option>,
        startDate: Binding<Date>,
        endDate: Binding<Date>,
        customOption: Option? = nil,
        onSelectionChanged: @escaping () -> Void = {}
    ) {
        _selection = selection
        _startDate = startDate
        _endDate = endDate
        self.customOption = customOption
        self.onSelectionChanged = onSelectionChanged
    }

    var body: some View {
        VStack(spacing: 10) {
            Picker("Period", selection: $selection) {
                ForEach(Array(Option.allCases), id: \.id) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selection) { _, _ in
                onSelectionChanged()
            }

            if customOption == selection {
                DateIntervalFields(startDate: $startDate, endDate: $endDate)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selection)
    }
}

struct PeriodSegmentedPicker<Option: Hashable & CaseIterable & Identifiable & RawRepresentable>: View where Option.RawValue == String {
    @Binding var selection: Option

    var body: some View {
        Picker("Period", selection: $selection) {
            ForEach(Array(Option.allCases), id: \.id) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct ValueStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        MetricCard(title: title, value: value, valueColor: .primary, valueFont: .headline) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: [Item.self, Budget.self, MonthlyBudgetSettings.self], inMemory: true)
}
