//
//  TrendsView.swift
//  Expense
//
//  Created by Harshit Agarwal on 01/03/26.
//

import SwiftUI
import SwiftData
import Charts
import TipKit

struct TrendsView: View {
    @Environment(\.analyticsFilterOptions) private var analyticsFilters
    @Query(sort: \Item.date) private var items: [Item]
    @Query private var monthlyBudgetSettings: [MonthlyBudgetSettings]
    
    @State private var trendPeriod: TrendPeriod = .last30Days
    @State private var selectedTrendDate: Date?
    @State private var selectedWeekday: String?
    @State private var selectedPaymentDate: Date?
    private let trendsTip = ViewTrendsTip()
    
    enum TrendPeriod: String, CaseIterable, Identifiable {
        case last7Days = "7 Days"
        case last30Days = "30 Days"
        case last90Days = "90 Days"
        
        var id: String { rawValue }
        
        var days: Int {
            switch self {
            case .last7Days: return 7
            case .last30Days: return 30
            case .last90Days: return 90
            }
        }
    }
    
    /// Inclusive current-period start where today is the last day of the window.
    /// Example: 7-day period => start is 6 days ago (today included).
    var startDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -(trendPeriod.days - 1), to: today) ?? today
    }
    
    var itemsAfterInspectorFilters: [Item] {
        items.filter { item in
            let categoryMatches = analyticsFilters.category == nil || item.category == analyticsFilters.category
            let methodMatches = analyticsFilters.paymentMethod == nil || item.paymentMethod == analyticsFilters.paymentMethod
            return categoryMatches && methodMatches
        }
    }

    var filteredItems: [Item] {
        itemsAfterInspectorFilters.filter { $0.date >= startDate }
    }

    var previousPeriodItems: [Item] {
        let calendar = Calendar.current
        let currentStart = calendar.startOfDay(for: startDate)
        let previousStart = calendar.date(byAdding: .day, value: -trendPeriod.days, to: currentStart) ?? currentStart
        return itemsAfterInspectorFilters.filter { $0.date >= previousStart && $0.date < currentStart }
    }
    
    var dailyTotals: [(date: Date, amount: Double)] {
        let grouped = Dictionary(grouping: filteredItems) { item in
            Calendar.current.startOfDay(for: item.date)
        }
        return grouped.map { (date: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.date < $1.date }
    }
    
    var movingAverage: [(date: Date, average: Double)] {
        let window = min(7, dailyTotals.count)
        guard dailyTotals.count >= window, window > 0 else {
            return dailyTotals.map { ($0.date, $0.amount) }
        }
        
        var result: [(date: Date, average: Double)] = []
        for i in (window - 1)..<dailyTotals.count {
            let slice = dailyTotals[(i - window + 1)...i]
            let avg = slice.reduce(0.0) { $0 + $1.amount } / Double(window)
            result.append((dailyTotals[i].date, avg))
        }
        return result
    }
    
    var topCategories: [(category: ExpenseCategory, amount: Double)] {
        let dict = filteredItems.reduce(into: [ExpenseCategory: Double]()) { result, item in
            result[item.category, default: 0] += item.amount
        }
        let categoryTotals: [(category: ExpenseCategory, amount: Double)] = dict.map { key, value in
            (category: key, amount: value)
        }
        return categoryTotals
            .sorted(by: { lhs, rhs in lhs.amount > rhs.amount })
            .prefix(10)
            .map { $0 }
    }
    
    var averageDailySpend: Double {
        guard !dailyTotals.isEmpty else { return 0 }
        return dailyTotals.reduce(0) { $0 + $1.amount } / Double(dailyTotals.count)
    }
    
    var highestDay: (date: Date, amount: Double)? {
        dailyTotals.max(by: { $0.amount < $1.amount })
    }
    
    var lowestDay: (date: Date, amount: Double)? {
        dailyTotals.min(by: { $0.amount < $1.amount })
    }
    
    var totalSpend: Double {
        filteredItems.reduce(0) { $0 + $1.amount }
    }

    var previousPeriodTotal: Double {
        previousPeriodItems.reduce(0) { $0 + $1.amount }
    }

    var periodDeltaAmount: Double {
        totalSpend - previousPeriodTotal
    }

    var periodDeltaPercent: Double? {
        guard previousPeriodTotal > 0 else { return nil }
        return (periodDeltaAmount / previousPeriodTotal) * 100
    }

    var comparisonInsightText: String {
        guard let percent = periodDeltaPercent else {
            return "Not enough previous-period data for a full comparison."
        }
        if abs(percent) < 2 {
            return "Spending pace is almost unchanged vs previous period."
        }
        if percent > 0 {
            return "Spending pace is increasing vs previous period."
        }
        return "Spending pace is improving vs previous period."
    }

    var categoryMomentum: [(category: ExpenseCategory, current: Double, previous: Double, deltaPct: Double)] {
        let currentTotals = filteredItems.reduce(into: [ExpenseCategory: Double]()) { result, item in
            result[item.category, default: 0] += item.amount
        }
        let previousTotals = previousPeriodItems.reduce(into: [ExpenseCategory: Double]()) { result, item in
            result[item.category, default: 0] += item.amount
        }

        return currentTotals
            .map { category, current in
                let previous = previousTotals[category] ?? 0
                let deltaPct: Double
                if previous > 0 {
                    deltaPct = ((current - previous) / previous) * 100
                } else {
                    deltaPct = current > 0 ? 100 : 0
                }
                return (category: category, current: current, previous: previous, deltaPct: deltaPct)
            }
            .sorted { abs($0.deltaPct) > abs($1.deltaPct) }
            .prefix(5)
            .map { $0 }
    }

    var projectedMonthSpend: Double {
        let monthItems = ExpenseDataManager.currentMonthItems(from: itemsAfterInspectorFilters)
        let daysElapsed = max(Calendar.current.component(.day, from: Date()), 1)
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
        let monthSpent = monthItems.reduce(0) { $0 + $1.amount }
        let dailyRunRate = monthSpent / Double(daysElapsed)
        return dailyRunRate * Double(daysInMonth)
    }

    var monthlyBudgetDeltaText: String {
        guard let totalBudget = monthlyBudgetSettings.first?.monthlyTotalBudget, totalBudget > 0 else {
            return "Set monthly total budget to compare forecast."
        }
        let delta = projectedMonthSpend - totalBudget
        if abs(delta) < 0.5 {
            return "Forecast is aligned with your monthly total budget."
        }
        if delta > 0 {
            return "Forecast is ₹\(String(format: "%.0f", delta)) above budget."
        }
        return "Forecast is ₹\(String(format: "%.0f", abs(delta))) below budget."
    }

    var weekdaySpending: [(day: String, amount: Double)] {
        let formatter = DateFormatter()
        formatter.locale = .current
        let symbols = formatter.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        // Calendar weekday indexes are 1...7 with Sunday first.
        var totals = Array(repeating: 0.0, count: 7)
        filteredItems.forEach { item in
            let weekday = Calendar.current.component(.weekday, from: item.date)
            totals[max(0, min(6, weekday - 1))] += item.amount
        }

        return (0..<7).map { index in
            (day: symbols[index], amount: totals[index])
        }
    }

    var topWeekday: (day: String, amount: Double)? {
        weekdaySpending.max(by: { $0.amount < $1.amount })
    }

    private struct PaymentMethodDailyPoint: Identifiable {
        let date: Date
        let method: String
        let amount: Double
        var id: String { "\(date.timeIntervalSince1970)-\(method)" }
    }

    var paymentDailySeries: [PaymentMethodDailyPoint] {
        let grouped = filteredItems.reduce(into: [Date: [String: Double]]()) { result, item in
            let day = Calendar.current.startOfDay(for: item.date)
            let method = item.paymentMethod?.displayName ?? "Not Set"
            result[day, default: [:]][method, default: 0] += item.amount
        }

        return grouped
            .flatMap { day, methodTotals in
                methodTotals.map { method, amount in
                    PaymentMethodDailyPoint(date: day, method: method, amount: amount)
                }
            }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date { return lhs.method < rhs.method }
                return lhs.date < rhs.date
            }
    }

    var selectedTrendAmount: Double? {
        guard let selectedTrendDate else { return nil }
        let day = Calendar.current.startOfDay(for: selectedTrendDate)
        return dailyTotals.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) })?.amount
    }

    var selectedPaymentDayTotal: Double? {
        guard let selectedPaymentDate else { return nil }
        let day = Calendar.current.startOfDay(for: selectedPaymentDate)
        let total = paymentDailySeries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.amount }
        return total > 0 ? total : nil
    }

    var selectedWeekdayAmount: Double? {
        guard let selectedWeekday else { return nil }
        return weekdaySpending.first(where: { $0.day == selectedWeekday })?.amount
    }
    
    // Day-over-day spending growth
    var spendingTrend: String {
        guard dailyTotals.count >= 2 else { return "Insufficient data" }
        let halfPoint = dailyTotals.count / 2
        let firstHalf = dailyTotals.prefix(halfPoint).reduce(0.0) { $0 + $1.amount }
        let secondHalf = dailyTotals.suffix(dailyTotals.count - halfPoint).reduce(0.0) { $0 + $1.amount }
        
        if secondHalf > firstHalf * 1.1 {
            return "Spending is increasing"
        } else if secondHalf < firstHalf * 0.9 {
            return "Spending is decreasing"
        } else {
            return "Spending is stable"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TipView(trendsTip)
                    .padding(.horizontal)
                
                // Period picker
                PeriodSegmentedPicker(selection: $trendPeriod)
                .padding(.horizontal)
                
                if filteredItems.isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("No expenses found for the selected period.")
                    )
                } else {
                    // Stats row
                    HStack(spacing: 8) {
                        ValueStatCard(icon: "indianrupeesign.circle.fill", title: "Total", value: "₹\(String(format: "%.0f", totalSpend))", color: .blue)
                        ValueStatCard(icon: "chart.line.uptrend.xyaxis", title: "Daily Avg", value: "₹\(String(format: "%.0f", averageDailySpend))", color: .green)
                        if let highest = highestDay {
                            ValueStatCard(icon: "arrow.up.circle.fill", title: "Peak", value: "₹\(String(format: "%.0f", highest.amount))", color: .orange)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Trend indicator
                    HStack {
                        Image(systemName: spendingTrend.contains("increasing") ? "arrow.up.right" :
                                spendingTrend.contains("decreasing") ? "arrow.down.right" : "arrow.right")
                            .foregroundStyle(spendingTrend.contains("increasing") ? .red :
                                    spendingTrend.contains("decreasing") ? .green : .blue)
                        Text(spendingTrend)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal)

                    GroupBox("Period Comparison") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Current")
                                Spacer()
                                Text("₹\(String(format: "%.0f", totalSpend))")
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Text("Previous")
                                Spacer()
                                Text("₹\(String(format: "%.0f", previousPeriodTotal))")
                                    .fontWeight(.semibold)
                            }

                            Divider()

                            HStack {
                                Text("Delta")
                                Spacer()
                                Text("₹\(String(format: "%.0f", abs(periodDeltaAmount)))")
                                    .fontWeight(.bold)
                                    .foregroundStyle(periodDeltaAmount > 0 ? .red : periodDeltaAmount < 0 ? .green : .secondary)
                            }

                            if let percent = periodDeltaPercent {
                                HStack {
                                    Text("Delta %")
                                    Spacer()
                                    Label(
                                        "\(String(format: "%.0f", abs(percent)))%",
                                        systemImage: percent >= 0 ? "arrow.up.right" : "arrow.down.right"
                                    )
                                    .fontWeight(.semibold)
                                    .foregroundStyle(percent >= 0 ? .red : .green)
                                }
                            }

                            Text(comparisonInsightText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Daily spending trend chart
                    GroupBox("Daily Spending") {
                        Chart {
                            ForEach(dailyTotals, id: \.date) { entry in
                                BarMark(
                                    x: .value("Date", entry.date, unit: .day),
                                    y: .value("Amount", entry.amount)
                                )
                                .foregroundStyle(.blue.opacity(0.5))
                            }
                            
                            ForEach(movingAverage, id: \.date) { entry in
                                LineMark(
                                    x: .value("Date", entry.date, unit: .day),
                                    y: .value("Average", entry.average)
                                )
                                .foregroundStyle(.red)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            }

                            if let selectedTrendDate, let selectedTrendAmount {
                                RuleMark(x: .value("Selected Date", selectedTrendDate, unit: .day))
                                    .foregroundStyle(.gray.opacity(0.35))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text("\(selectedTrendDate.formatted(.dateTime.month(.abbreviated).day()))\n₹\(String(format: "%.0f", selectedTrendAmount))")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(6)
                                            .background(.ultraThinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                            }
                        }
                        .chartXSelection(value: $selectedTrendDate)
                        .chartYAxisLabel("Amount (₹)")
                        .frame(height: 250)
                        
                        HStack {
                            Circle().fill(.blue.opacity(0.5)).frame(width: 10, height: 10)
                            Text("Daily Spend").font(.caption)
                            Spacer()
                            Rectangle().fill(.red).frame(width: 20, height: 3)
                            Text("7-Day Moving Avg").font(.caption)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)

                    GroupBox("Weekday Heatmap") {
                        VStack(alignment: .leading, spacing: 10) {
                            Chart {
                                ForEach(weekdaySpending, id: \.day) { entry in
                                    BarMark(
                                        x: .value("Weekday", entry.day),
                                        y: .value("Amount", entry.amount)
                                    )
                                    .foregroundStyle(by: .value("Amount", entry.amount))
                                    .cornerRadius(4)
                                }

                                if let selectedWeekday, let selectedWeekdayAmount {
                                    RuleMark(x: .value("Selected Weekday", selectedWeekday))
                                        .foregroundStyle(.gray.opacity(0.35))
                                        .annotation(position: .top) {
                                            Text("\(selectedWeekday)\n₹\(String(format: "%.0f", selectedWeekdayAmount))")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .padding(6)
                                                .background(.ultraThinMaterial)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                            }
                            }
                            .chartXSelection(value: $selectedWeekday)
                            .chartForegroundStyleScale(
                                domain: [0, max(weekdaySpending.map(\.amount).max() ?? 1, 1)],
                                range: [Color.green.opacity(0.35), Color.orange, Color.red]
                            )
                            .chartLegend(.hidden)
                            .frame(height: 180)

                            if let busiest = topWeekday {
                                Text("Highest weekday spend: \(busiest.day) (₹\(String(format: "%.0f", busiest.amount))).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)

                    GroupBox("Payment Method Trend") {
                        Chart {
                            ForEach(paymentDailySeries) { entry in
                                BarMark(
                                    x: .value("Date", entry.date, unit: .day),
                                    y: .value("Amount", entry.amount)
                                )
                                .foregroundStyle(by: .value("Payment Method", entry.method))
                            }

                            if let selectedPaymentDate, let selectedPaymentDayTotal {
                                RuleMark(x: .value("Selected Date", selectedPaymentDate, unit: .day))
                                    .foregroundStyle(.gray.opacity(0.35))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text("\(selectedPaymentDate.formatted(.dateTime.month(.abbreviated).day()))\n₹\(String(format: "%.0f", selectedPaymentDayTotal))")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(6)
                                            .background(.ultraThinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                            }
                        }
                        .chartXSelection(value: $selectedPaymentDate)
                        .chartLegend(position: .bottom, alignment: .leading)
                        .frame(height: 260)
                    }
                    .padding(.horizontal)
                    
                    // Category spending distribution
                    GroupBox("Top Categories") {
                        VStack(spacing: 12) {
                            ForEach(topCategories, id: \.category) { entry in
                                HStack {
                                    Text(entry.category.displayName)
                                        .font(.subheadline)
                                        .frame(width: 120, alignment: .leading)
                                    
                                    let maxAmount = topCategories.first?.amount ?? 1
                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(.blue.gradient)
                                            .frame(width: geo.size.width * (entry.amount / maxAmount))
                                    }
                                    .frame(height: 20)
                                    
                                    Text("₹\(String(format: "%.0f", entry.amount))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .frame(width: 60, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    GroupBox("Category Momentum") {
                        VStack(spacing: 10) {
                            if categoryMomentum.isEmpty {
                                Text("Not enough data to compare with previous period.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(categoryMomentum, id: \.category) { entry in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.category.displayName)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text("Now ₹\(String(format: "%.0f", entry.current)) vs Prev ₹\(String(format: "%.0f", entry.previous))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        let up = entry.deltaPct >= 0
                                        Label("\(String(format: "%.0f", abs(entry.deltaPct)))%", systemImage: up ? "arrow.up.right" : "arrow.down.right")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(up ? .red : .green)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    GroupBox("Month-End Forecast") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Projected Spend")
                                Spacer()
                                Text("₹\(String(format: "%.0f", projectedMonthSpend))")
                                    .fontWeight(.bold)
                            }

                            Text(monthlyBudgetDeltaText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Day details
                    GroupBox("Day Details") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let highest = highestDay {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundStyle(.orange)
                                    Text("Highest: \(highest.date.formatted(.dateTime.month(.abbreviated).day()))")
                                    Spacer()
                                    Text("₹\(String(format: "%.0f", highest.amount))")
                                        .fontWeight(.bold)
                                }
                            }
                            if let lowest = lowestDay {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Lowest: \(lowest.date.formatted(.dateTime.month(.abbreviated).day()))")
                                    Spacer()
                                    Text("₹\(String(format: "%.0f", lowest.amount))")
                                        .fontWeight(.bold)
                                }
                            }
                            HStack {
                                Image(systemName: "number.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Total entries")
                                Spacer()
                                Text("\(filteredItems.count)")
                                    .fontWeight(.bold)
                            }
                            HStack {
                                Image(systemName: "calendar.circle.fill")
                                    .foregroundStyle(.purple)
                                Text("Active days")
                                Spacer()
                                Text("\(dailyTotals.count)")
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .animation(.easeInOut(duration: 0.25), value: trendPeriod)
        .onAppear {
            ViewTrendsTip.hasViewedTrends = true
        }
    }
}

#Preview {
    TrendsView()
        .modelContainer(for: Item.self, inMemory: true)
}
