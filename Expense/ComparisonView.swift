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
    
    var periodAItems: [Item] {
        items.filter { $0.date >= periodAStart && $0.date <= periodAEnd }
    }
    
    var periodBItems: [Item] {
        items.filter { $0.date >= periodBStart && $0.date <= periodBEnd }
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
                    HStack {
                        DatePicker("From", selection: $periodAStart, displayedComponents: .date)
                        DatePicker("To", selection: $periodAEnd, displayedComponents: .date)
                    }
                }
                .padding(.horizontal)
                
                GroupBox("Period B (Previous)") {
                    HStack {
                        DatePicker("From", selection: $periodBStart, displayedComponents: .date)
                        DatePicker("To", selection: $periodBEnd, displayedComponents: .date)
                    }
                }
                .padding(.horizontal)

                Toggle("Flip A/B Perspective", isOn: $isFlipped)
                    .padding(.horizontal)
                
                // Summary Cards
                HStack(spacing: 12) {
                    SummaryCard(title: primaryTitle, amount: primaryTotal, color: .blue)
                    SummaryCard(title: secondaryTitle, amount: secondaryTotal, color: .orange)
                    SummaryCard(
                        title: "Change",
                        amount: flippedPercentChange,
                        color: flippedPercentChange > 0 ? .red : .green,
                        isPercent: true
                    )
                }
                .padding(.horizontal)
                
                // Comparison Chart
                if !comparisonData.isEmpty {
                    GroupBox("Category Comparison") {
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
                    GroupBox("Category Breakdown") {
                        VStack(spacing: 0) {
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
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    var isPercent: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(isPercent
                 ? "\(amount >= 0 ? "+" : "")\(String(format: "%.1f", amount))%"
                 : "₹\(String(format: "%.0f", amount))")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ComparisonView()
        .modelContainer(for: Item.self, inMemory: true)
}
