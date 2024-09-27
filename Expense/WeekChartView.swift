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

    var body: some View {
        @State var dailyItems = items.reduce(into: [Date: Double]()) { result, item in
            let day = Calendar.current.startOfDay(for: item.date)
            result[day, default: 0] += item.totalAmount
        }
        @State var mostRecentDate = dailyItems.keys.max() ?? Date()

        func calculateTotalAmount(for startDate: Date, rangeInDays: Int) -> Double {
            let endDate = startDate.addingTimeInterval(TimeInterval(rangeInDays * 24 * 3600))

            return dailyItems.filter { $0.key >= startDate && $0.key <= endDate }.reduce(0) { $0 + $1.value }
        }

        return VStack {
            Chart(dailyItems.sorted(by: { $0.key < $1.key }), id: \.key) { date, amount in
                BarMark(
                    x: .value("Day", date, unit: .day),
                    y: .value("Amount", amount)
                )
                if let selectedDay {
                    RuleMark(x: .value("Selected", selectedDay, unit: .day))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 3600 * 24 * 7)
            .chartScrollPosition(x: $scrollPosition)
            .onAppear {
                scrollPosition = mostRecentDate.addingTimeInterval(-6 * 3600 * 24)
            }
            .onChange(of: selectedDay) { _ in
                if let selectedDay {
                    amountOnSelectedDay = dailyItems[Calendar.current.startOfDay(for: selectedDay)]
                }
            }
            .onChange(of: scrollPosition) { newScrollPosition in
                totalAmount = calculateTotalAmount(for: newScrollPosition, rangeInDays: 7)
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

