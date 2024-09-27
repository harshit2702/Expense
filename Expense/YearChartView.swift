//
//  YearChartView.swift
//  Expense
//
//  Created by Harshit Agarwal on 16/07/24.
//

import SwiftUI
import Charts

struct YearChartView: View {
    @State var items: [CategorySummary]
    @Binding var selectedMonth: Date?
    @Binding var scrollPosition: Date
    @Binding var amountOnSelectedMonth: Double?
    @Binding var totalAmount: Double?

    var body: some View {
        @State var monthlyItems = items.reduce(into: [Date: Double]()) { result, item in
            // Assuming 'CategorySummary' has a 'date' and 'totalAmount' property
            let month = Calendar.current.dateInterval(of: .month, for: item.date)!.start
            result[month, default: 0] += item.totalAmount
        }

        @State var mostRecentDate = monthlyItems.keys.max() ?? Date()

        func calculateTotalAmount(for startDate: Date, rangeInDays: Int) -> Double {
            // Break the expression into smaller steps to improve compiler performance
            let endDate = startDate.addingTimeInterval(TimeInterval(rangeInDays * 24 * 3600))
            let filteredItems = monthlyItems.filter { $0.key >= startDate && $0.key <= endDate }
            let totalAmount = filteredItems.reduce(0) { (result, item) -> Double in
                return result + item.value
            }
            return totalAmount
        }

        return VStack {
            Chart(monthlyItems.sorted(by: { $0.key < $1.key }), id: \.key) { date, amount in
                BarMark(
                    x: .value("Month", date, unit: .month),
                    y: .value("Amount", amount)
                )
                if let selectedMonth {
                    RuleMark(x: .value("Selected", selectedMonth, unit: .month))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 3600 * 24 * 365)
            .chartScrollPosition(x: $scrollPosition)
            .onAppear {
                scrollPosition = mostRecentDate.addingTimeInterval(-336 * 24 * 3600)
            }
            .onChange(of: selectedMonth) { newValue in
                if let selectedMonth = newValue {
                    let startOfMonth = Calendar.current.dateInterval(of: .month, for: selectedMonth)?.start ?? Date()
                    amountOnSelectedMonth = monthlyItems[startOfMonth]
                }
            }
            .onChange(of: scrollPosition) { newScrollPosition in
                totalAmount = calculateTotalAmount(for: newScrollPosition, rangeInDays: 365)
            }
            .chartXSelection(value: $selectedMonth)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 1)) {
                    AxisTick()
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
        }
    }
}

