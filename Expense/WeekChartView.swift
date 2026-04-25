//
//  WeekChartView.swift
//  Expense
//
//  Created by Harshit Agarwal on 16/07/24.
//

import SwiftUI
import SwiftData
import Charts

struct WeekChartView: View {
    @State var items: [CategorySummary]
    @Binding var selectedDay: Date?
    @Binding var scrollPosition: Date
    @Binding var amountOnSelectedDay: Double?
    @Binding var totalAmount: Double?

    private var dailyItems: [Date: Double] {
        items.reduce(into: [Date: Double]()) { result, item in
            let day = Calendar.current.startOfDay(for: item.date)
            result[day, default: 0] += item.totalAmount
        }
    }

    private var mostRecentDate: Date {
        dailyItems.keys.max() ?? Date()
    }

    private func calculateTotalAmount(for startDate: Date, rangeInDaysExclusive: Int) -> Double {
        let endExclusive = startDate.addingTimeInterval(TimeInterval(rangeInDaysExclusive * 24 * 3600))
        return dailyItems.filter { $0.key >= startDate && $0.key < endExclusive }.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        VStack {
            Chart(dailyItems.sorted(by: { $0.key < $1.key }), id: \.key) { date, amount in
                BarMark(
                    x: .value("Day", date, unit: .day),
                    y: .value("Amount", amount)
                )
                if let selectedDay {
                    RuleMark(x: .value("Selected", selectedDay, unit: .day))
                        .foregroundStyle(Color.gray.opacity(0.3))
                        .annotation(position: .top, alignment: .leading) {
                            if let amt = dailyItems[Calendar.current.startOfDay(for: selectedDay)] {
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
            .chartXVisibleDomain(length: 3600 * 24 * 7)
            .chartScrollPosition(x: $scrollPosition)
            .onAppear {
                scrollPosition = mostRecentDate.addingTimeInterval(-6 * 3600 * 24)
                totalAmount = calculateTotalAmount(for: scrollPosition, rangeInDaysExclusive: 7)
            }
            .onChange(of: selectedDay) { _, newValue in
                if let newValue {
                    amountOnSelectedDay = dailyItems[Calendar.current.startOfDay(for: newValue)]
                }
            }
            .onChange(of: scrollPosition) { _, newScrollPosition in
                totalAmount = calculateTotalAmount(for: newScrollPosition, rangeInDaysExclusive: 7)
            }
            .chartXSelection(value: $selectedDay)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1)) {
                    AxisTick()
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday())
                }
            }
        }
    }
}
