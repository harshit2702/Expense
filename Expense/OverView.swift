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
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    private let overviewTip = OverviewTip()
    
    var categoryAmount: [(category: ExpenseCategory, amount: Double, cumulativeAmountSt: Double, cumulativeAmountEnd: Double)] {
        let filteredItems = items.filter { item in
                item.date >= startDate && item.date <= endDate
            }
            
            let amountDict = filteredItems.reduce(into: [ExpenseCategory: Double]()) { result, item in
                let category = item.category
                result[category, default: 0] += item.amount
            }
            
            let sortedCategories = amountDict.keys.sorted()
            var cumulativeSum: Double = 0
            return sortedCategories.map { category in
                let amount = amountDict[category]!
                cumulativeSum += amount
                return (category, amount, cumulativeSum - amount, cumulativeSum)
            }
        }
    
    @State private var selectedCategoryAmount: Double?
    @State private var selectedCategory: String = "None"
    @State private var selectedPrice: Double = 0.0 // Assuming price is a Double
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var dateRangeType: DateRangeType = .last7Days

    enum DateRangeType: String, CaseIterable, Identifiable{
        case last7Days = "Last 7 Days"
        case last14Days = "Last 14 Days"
        case last30Days = "Last 30 Days"
        case custom = "Custom"
        
        var id: String { self.rawValue }
    }

    var body: some View {
        VStack {
            VStack {
                TipView(overviewTip)
                    .padding(.horizontal)
                
                Text(selectedCategory)
                Text("Amount Spent: \u{20B9}\(String(format: "%.2f", selectedPrice))")
                
                Picker("Date Range", selection: $dateRangeType) {
                    ForEach(DateRangeType.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: dateRangeType) { _, _ in
                    updateDateRange()
                }
                
                // Show Date Pickers only for Custom Date Range
                if dateRangeType == .custom {
                    VStack {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    }
                    .padding()
                }
                
                Chart(categoryAmount, id: \.category) { entry in
                    SectorMark(
                        angle: .value("Category", entry.amount),
                        innerRadius: .ratio(0.314),
                        angularInset: 2.0
                    )
                    .foregroundStyle(by: .value("Category", entry.category.displayName))
                }
                .chartAngleSelection(value: $selectedCategoryAmount)
                .padding()
                    
                }
            Rectangle()
                .frame(height: 2.0)
            ChartView(categories: ExpenseCategory.allCases)
            Rectangle()
                .frame(height: 2.0)
        }
        .onChange(of: selectedCategoryAmount) { _, newValue in
            if let selectedAmount = newValue {
                if let categoryEntry = categoryAmount.first(where: { $0.cumulativeAmountSt <= selectedAmount && selectedAmount < $0.cumulativeAmountEnd }) {
                    selectedCategory = categoryEntry.category.displayName
                    selectedPrice = categoryEntry.amount
                } else {
                    selectedCategory = "None"
                    selectedPrice = 0.0
                }
            }
        }
    }
    
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
            // Do nothing, custom dates are set by the user
            break
        }
    }
}

#Preview {
    OverviewView()
}
