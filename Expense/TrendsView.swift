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
    @Query(sort: \Item.date) private var items: [Item]
    
    @State private var trendPeriod: TrendPeriod = .last30Days
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
    
    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -trendPeriod.days, to: Date()) ?? Date()
    }
    
    var filteredItems: [Item] {
        items.filter { $0.date >= startDate }
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
                Picker("Period", selection: $trendPeriod) {
                    ForEach(TrendPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
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
                        StatCard(title: "Total", value: "₹\(String(format: "%.0f", totalSpend))", icon: "indianrupeesign.circle.fill", color: .blue)
                        StatCard(title: "Daily Avg", value: "₹\(String(format: "%.0f", averageDailySpend))", icon: "chart.line.uptrend.xyaxis", color: .green)
                        if let highest = highestDay {
                            StatCard(title: "Peak", value: "₹\(String(format: "%.0f", highest.amount))", icon: "arrow.up.circle.fill", color: .orange)
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
                        }
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
        .onAppear {
            ViewTrendsTip.hasViewedTrends = true
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    TrendsView()
        .modelContainer(for: Item.self, inMemory: true)
}
