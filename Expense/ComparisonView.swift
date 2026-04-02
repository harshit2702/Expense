//
//  ComparisonView.swift
//  Expense
//
//  Created by Harshit Agarwal on 01/03/26.
//

import SwiftUI
import SwiftData
import Charts
import TipKit

struct ComparisonView: View {
    @Environment(\.analyticsFilterOptions) private var analyticsFilters
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    private let compareTip = CompareSpendingTip()
    
    @State private var periodAStart: Date
    @State private var periodAEnd: Date
    @State private var periodBStart: Date
    @State private var periodBEnd: Date
    @State private var isFlipped = false
    
    init() {
        let now = Date()
        let cal = Calendar.current
        let monthAgo = cal.date(byAdding: .month, value: -1, to: now)!
        let twoMonthsAgo = cal.date(byAdding: .month, value: -2, to: now)!
        _periodAStart = State(initialValue: monthAgo)
        _periodAEnd = State(initialValue: now)
        _periodBStart = State(initialValue: twoMonthsAgo)
        _periodBEnd = State(initialValue: monthAgo)
    }
    
    private var itemsAfterInspectorFilters: [Item] {
        items.filter { item in
            let categoryMatches = analyticsFilters.category == nil || item.category == analyticsFilters.category
            let methodMatches = analyticsFilters.paymentMethod == nil || item.paymentMethod == analyticsFilters.paymentMethod
            return categoryMatches && methodMatches
        }
    }

    var periodAItems: [Item] {
        itemsAfterInspectorFilters.filter { $0.date >= periodAStart && $0.date <= periodAEnd }
    }
    
    var periodBItems: [Item] {
        itemsAfterInspectorFilters.filter { $0.date >= periodBStart && $0.date <= periodBEnd }
    }
    
    var periodATotal: Double { periodAItems.reduce(0) { $0 + $1.amount } }
    var periodBTotal: Double { periodBItems.reduce(0) { $0 + $1.amount } }
    
    var percentChange: Double {
        guard periodBTotal > 0 else { return 0 }
        return ((periodATotal - periodBTotal) / periodBTotal) * 100
    }

    private var primaryTitle: String { isFlipped ? "Period B" : "Period A" }
    private var secondaryTitle: String { isFlipped ? "Period A" : "Period B" }
    private var primaryLegend: String { isFlipped ? "Previous" : "Current" }
    private var secondaryLegend: String { isFlipped ? "Current" : "Previous" }
    private var primaryTotal: Double { isFlipped ? periodBTotal : periodATotal }
    private var secondaryTotal: Double { isFlipped ? periodATotal : periodBTotal }
    private var flippedPercentChange: Double {
        guard secondaryTotal > 0 else { return 0 }
        return ((primaryTotal - secondaryTotal) / secondaryTotal) * 100
    }
    
    var comparisonData: [(category: ExpenseCategory, periodA: Double, periodB: Double)] {
        var dictA = [ExpenseCategory: Double]()
        var dictB = [ExpenseCategory: Double]()
        
        for item in periodAItems { dictA[item.category, default: 0] += item.amount }
        for item in periodBItems { dictB[item.category, default: 0] += item.amount }
        
        let allCategories = Set(dictA.keys).union(dictB.keys).sorted()
        return allCategories.map { cat in
            (cat, dictA[cat] ?? 0, dictB[cat] ?? 0)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TipView(compareTip)
                    .padding(.horizontal)
                    .onAppear { CompareSpendingTip.hasCompared = true }

                // Period Selectors
                GroupBox("Period A (Current)") {
                    DateIntervalFields(startDate: $periodAStart, endDate: $periodAEnd)
                }
                .padding(.horizontal)
                
                GroupBox("Period B (Previous)") {
                    DateIntervalFields(startDate: $periodBStart, endDate: $periodBEnd)
                }
                .padding(.horizontal)

                Toggle("Flip A/B Perspective", isOn: $isFlipped)
                    .padding(.horizontal)
                
                // Summary Cards
                HStack(spacing: 12) {
                    MetricCard(
                        title: primaryTitle,
                        value: "₹\(String(format: "%.0f", primaryTotal))",
                        valueColor: .blue,
                        overlayTint: .blue
                    )
                    MetricCard(
                        title: secondaryTitle,
                        value: "₹\(String(format: "%.0f", secondaryTotal))",
                        valueColor: .orange,
                        overlayTint: .orange
                    )
                    MetricCard(
                        title: "Change",
                        value: "\(flippedPercentChange >= 0 ? "+" : "")\(String(format: "%.1f", flippedPercentChange))%",
                        valueColor: flippedPercentChange > 0 ? .red : .green,
                        overlayTint: flippedPercentChange > 0 ? .red : .green
                    )
                }
                .padding(.horizontal)
                
                // Comparison Chart
                if !comparisonData.isEmpty {
                    ChartContainer(title: "Category Comparison") {
                        Chart(comparisonData, id: \.category) { entry in
                            let primaryAmount = isFlipped ? entry.periodB : entry.periodA
                            let secondaryAmount = isFlipped ? entry.periodA : entry.periodB

                            BarMark(
                                x: .value("Category", entry.category.displayName),
                                y: .value("Amount", primaryAmount)
                            )
                            .foregroundStyle(by: .value("Period", primaryLegend))
                            .position(by: .value("Period", primaryLegend))
                            
                            BarMark(
                                x: .value("Category", entry.category.displayName),
                                y: .value("Amount", secondaryAmount)
                            )
                            .foregroundStyle(by: .value("Period", secondaryLegend))
                            .position(by: .value("Period", secondaryLegend))
                        }
                        .chartForegroundStyleScale([primaryLegend: .blue, secondaryLegend: .orange])
                        .frame(height: 300)
                        .accessibilityLabel("Category comparison chart")
                        .accessibilityValue("Compares \(comparisonData.count) categories across two periods")
                    }
                    .padding(.horizontal)
                } else {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.bar",
                        description: Text("No expenses found in the selected periods.")
                    )
                }
                
                // Category Breakdown Table
                if !comparisonData.isEmpty {
                    CardSurface {
                        VStack(spacing: 0) {
                            Text("Category Breakdown")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 8)

                            // Header
                            HStack {
                                Text("Category")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(primaryLegend)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
                                    .frame(width: 70, alignment: .trailing)
                                Text(secondaryLegend)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.orange)
                                    .frame(width: 70, alignment: .trailing)
                                Text("Change")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .padding(.bottom, 8)
                            
                            Divider()
                            
                            ForEach(comparisonData, id: \.category) { entry in
                                let primaryAmount = isFlipped ? entry.periodB : entry.periodA
                                let secondaryAmount = isFlipped ? entry.periodA : entry.periodB

                                HStack {
                                    Text(entry.category.displayName)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("₹\(String(format: "%.0f", primaryAmount))")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                        .frame(width: 70, alignment: .trailing)
                                    Text("₹\(String(format: "%.0f", secondaryAmount))")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                        .frame(width: 70, alignment: .trailing)
                                    
                                    let change = secondaryAmount > 0
                                        ? ((primaryAmount - secondaryAmount) / secondaryAmount * 100)
                                        : (primaryAmount > 0 ? 100 : 0)
                                    Text("\(change >= 0 ? "+" : "")\(String(format: "%.0f", change))%")
                                        .font(.subheadline)
                                        .foregroundStyle(change > 0 ? .red : .green)
                                        .frame(width: 60, alignment: .trailing)
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .animation(.easeInOut(duration: 0.25), value: isFlipped)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    openWindow(id: "comparison-window")
                } label: {
                    Label("Open in New Window", systemImage: "macwindow")
                }
            }
        }
    }
}

#Preview {
    ComparisonView()
        .modelContainer(for: Item.self, inMemory: true)
}
