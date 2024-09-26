//
//  YearChartView.swift
//  Expense
//
//  Created by Harshit Agarwal on 16/07/24.
//

import SwiftUI
import SwiftData
import Charts


struct YearChartView: View {
    @Binding var items: [Item]
    @Binding var selectedMonth: Date?
    @Binding var scrollPosition: Date
    @Binding var amountOnSelectedMonth: Double?
    @Binding var totalAmount: Double?

    var body: some View {
        @State var monthlyItems = items.reduce(into: [Date: Double]()) { result, item in
            let month = Calendar.current.dateInterval(of: .month, for: item.date)!.start
            result[month, default: 0] += item.amount
        }
        
        @State var mostRecentDate = monthlyItems.keys.max() ?? Date()
        
        func calculateTotalAmount(for startDate: Date, rangeInDays: Int) -> Double {
            let endDate = startDate.addingTimeInterval(TimeInterval(rangeInDays * 24 * 3600))
            return monthlyItems.filter { $0.key >= startDate && $0.key <= endDate }.reduce(0) { $0 + $1.value }
        }
        
        return VStack{
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
            .onAppear(perform: {
                scrollPosition = mostRecentDate.addingTimeInterval(-336 * 24 * 3600)
            })
            .chartXSelection(value: $selectedMonth)
            .onChange(of: selectedMonth) { newValue in
                if let selectedMonth = newValue {
                    let startOfMonth = Calendar.current.dateInterval(of: .month, for: selectedMonth)?.start ?? Date()
                    amountOnSelectedMonth = monthlyItems[startOfMonth]
                }
            }
            .onChange(of: scrollPosition){ newScrollPosition in
                totalAmount = calculateTotalAmount(for: newScrollPosition, rangeInDays: 365)
            }
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

#Preview {
    YearChartView(items: .constant(sampleItems), selectedMonth: .constant(Date()), scrollPosition: .constant(Date()), amountOnSelectedMonth: .constant(0.0), totalAmount: .constant(0.0))
}
