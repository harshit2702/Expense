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

    private var monthlyItems: [Date: Double] {
        items.reduce(into: [Date: Double]()) { result, item in
            let month = Calendar.current.dateInterval(of: .month, for: item.date)!.start
            result[month, default: 0] += item.totalAmount
        }
    }

    private var mostRecentDate: Date {
        monthlyItems.keys.max() ?? Date()
    }

    private func calculateTotalAmount(for startDate: Date, rangeInDays: Int) -> Double {
        let endDate = startDate.addingTimeInterval(TimeInterval(rangeInDays * 24 * 3600))
        let filteredItems = monthlyItems.filter { $0.key >= startDate && $0.key <= endDate }
        return filteredItems.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        VStack {
            Chart(monthlyItems.sorted(by: { $0.key < $1.key }), id: \.key) { date, amount in
                BarMark(
                    x: .value("Month", date, unit: .month),
                    y: .value("Amount", amount)
                )
                .annotation(position: .top, spacing: 2) {
                    if amount > 0 {
                        Text("\(Int(amount))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let selectedMonth {
                    RuleMark(x: .value("Selected", selectedMonth, unit: .month))
                        .foregroundStyle(Color.gray.opacity(0.3))
                        .annotation(position: .top, alignment: .leading) {
                            if let amt = monthlyItems[Calendar.current.dateInterval(of: .month, for: selectedMonth)?.start ?? Date()] {
                                Text("₹\(String(format: "%.0f", amt))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 3600 * 24 * 365)
            .chartScrollPosition(x: $scrollPosition)
            .onAppear {
                scrollPosition = mostRecentDate.addingTimeInterval(-336 * 24 * 3600)
            }
            .onChange(of: selectedMonth) { _, newValue in
                if let newValue {
                    let startOfMonth = Calendar.current.dateInterval(of: .month, for: newValue)?.start ?? Date()
                    amountOnSelectedMonth = monthlyItems[startOfMonth]
                }
            }
            .onChange(of: scrollPosition) { _, newScrollPosition in
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

