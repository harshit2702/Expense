//
//  ChartView.swift
//  Expense
//
//  Created by Harshit Agarwal on 15/07/24.
//

import SwiftUI
import SwiftData
import Charts

enum TimeRange: String, CaseIterable, Identifiable {
    case week, month, year
    var id: String { self.rawValue }
}

struct ChartView: View {
    @Environment(\.modelContext) private var modelContext
    @State var categories: [Categorys] = [.food]  // User-selected categories
    @State private var selectedTimeRange: TimeRange = .month
    @State var selectedDay: Date?
    @State var selectedMonth: Date?
    @State var scrollPosition: Date = Date()
    @State var amountOnSelectedDay: Double?
    @State var totalAmount: Double?
    @State var amountOnSelectedMonth: Double?

    // Pre-aggregated summary based on the time range
    var summaryItems: [CategorySummary] {
        fetchSummaryItems(for: selectedTimeRange)
    }

    var body: some View {
        GeometryReader { geo in
            HStack {
                VStack {
                    // Displaying amount info based on the selected date or month
                    switch selectedTimeRange {
                    case .week:
                        if let selectedDay = selectedDay {
                            Text("On \(selectedDay.formatted(.dateTime.year().month().day())) spent: \(amountOnSelectedDay ?? 0.0, specifier: "%.2f")")
                        } else {
                            Text("Total: \(totalAmount ?? 0.0, specifier: "%.2f") during this week")
                        }
                        Text("\(scrollPosition.formatted(.dateTime.month().day())) - \(scrollPosition.addingTimeInterval(6 * 3600 * 24).formatted(.dateTime.month().day()))")
                    case .month:
                        if let selectedDay = selectedDay {
                            Text("On \(selectedDay.formatted(.dateTime.year(.twoDigits).month(.abbreviated).day())) the amount spent is \(amountOnSelectedDay ?? 0.0, specifier: "%.2f")")
                        } else {
                            Text("Total Amount \(totalAmount ?? 0.0, specifier: "%.2f") during")
                        }
                    Text("\(scrollPosition.formatted(.dateTime.month(.abbreviated).day()))-\(scrollPosition.addingTimeInterval(29 * 3600 * 24).formatted(.dateTime.year(.twoDigits).month(.abbreviated).day()))")
                    case .year:
                        if let selectedMonth = selectedMonth {
                            Text("On \(selectedMonth.formatted(.dateTime.year(.twoDigits).month(.abbreviated))) the amount spent is \(amountOnSelectedMonth ?? 0.0, specifier: "%.2f")")
                        } else {
                            Text("Total Amount \(totalAmount ?? 0.0, specifier: "%.2f") during")
                        }
                        let startOfYear = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: scrollPosition)) ?? Date()
                    let endOfYear = Calendar.current.date(byAdding: DateComponents(year: 1,month: -1), to: startOfYear) ?? Date()
                        Text("\(startOfYear.formatted(.dateTime.year(.twoDigits).month(.abbreviated)))-\(endOfYear.formatted(.dateTime.year(.twoDigits).month(.abbreviated)))")
                    }
                }
                .frame(width: geo.size.width * 0.3)

                VStack {
                    Picker(selection: $selectedTimeRange) {
                        Text("Week").tag(TimeRange.week)
                        Text("Month").tag(TimeRange.month)
                        Text("Year").tag(TimeRange.year)
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)


                    switch selectedTimeRange {
                    case .week:
                        WeekChartView(items: summaryItems, selectedDay: $selectedDay, scrollPosition: $scrollPosition, amountOnSelectedDay: $amountOnSelectedDay, totalAmount: $totalAmount)
                    case .month:

                        MonthChartView(items: summaryItems, selectedDay: $selectedDay, scrollPosition: $scrollPosition, amountOnSelectedDay: $amountOnSelectedDay, totalAmount: $totalAmount)
                    case .year:
                        YearChartView(items: summaryItems, selectedMonth: $selectedMonth, scrollPosition: $scrollPosition, amountOnSelectedMonth: $amountOnSelectedMonth, totalAmount: $totalAmount)
                    }
                }
                .padding()
            }
        }
    }

    func fetchSummaryItems(for timeRange: TimeRange) -> [CategorySummary] {
        do {
            var fetchedItems: [CategorySummary] = []

            switch timeRange {
            case .week, .month:
                // Fetch daily summaries for the week and month range
                let dailySummaries = try modelContext.fetch(FetchDescriptor<DailyCategorySummary>())
                
                // Filter the daily summaries for the correct month or week
                fetchedItems = dailySummaries.filter {
                    // Calculate the start of the current month based on `scrollPosition`
                    let startOfMonth = Calendar.current.dateInterval(of: .month, for: scrollPosition)?.start ?? Date()
                    return $0.date >= startOfMonth && categories.contains($0.category)
                }

            case .year:
                // Fetch monthly summaries for the year range
                let monthlySummaries = try modelContext.fetch(FetchDescriptor<MonthlyCategorySummary>())
                
                fetchedItems = monthlySummaries.filter {
                    // Calculate the start of the current year based on `scrollPosition`
                    let startOfYear = Calendar.current.dateInterval(of: .year, for: scrollPosition)?.start ?? Date()
                    return $0.date >= startOfYear && categories.contains($0.category)
                }
            }

            // Debugging: Print the fetched items
            print("Fetched summary items: \(fetchedItems)")
            return fetchedItems
        } catch {
            print("Error fetching summary items: \(error)")
            return []
        }
    }


}
#Preview {
    ChartView()
}
