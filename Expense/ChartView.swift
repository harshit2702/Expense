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
    @State var categories: [ExpenseCategory] = [.food]
    @State private var selectedTimeRange: TimeRange = .month
    @State var selectedDay: Date?
    @State var selectedMonth: Date?
    @State var scrollPosition: Date = Date()
    @State var amountOnSelectedDay: Double?
    @State var totalAmount: Double?
    @State var amountOnSelectedMonth: Double?

    var summaryItems: [CategorySummary] {
        fetchSummaryItems(for: selectedTimeRange)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Time range picker
            Picker(selection: $selectedTimeRange) {
                Text("Week").tag(TimeRange.week)
                Text("Month").tag(TimeRange.month)
                Text("Year").tag(TimeRange.year)
            } label: { EmptyView() }
            .pickerStyle(.segmented)

            // Summary text
            summaryLabel
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Chart
            switch selectedTimeRange {
            case .week:
                WeekChartView(items: summaryItems, selectedDay: $selectedDay, scrollPosition: $scrollPosition, amountOnSelectedDay: $amountOnSelectedDay, totalAmount: $totalAmount)
            case .month:
                MonthChartView(items: summaryItems, selectedDay: $selectedDay, scrollPosition: $scrollPosition, amountOnSelectedDay: $amountOnSelectedDay, totalAmount: $totalAmount)
            case .year:
                YearChartView(items: summaryItems, selectedMonth: $selectedMonth, scrollPosition: $scrollPosition, amountOnSelectedMonth: $amountOnSelectedMonth, totalAmount: $totalAmount)
            }
        }
    }

    @ViewBuilder
    private var summaryLabel: some View {
        switch selectedTimeRange {
        case .week:
            if let selectedDay, let amt = amountOnSelectedDay {
                Text("\(selectedDay.formatted(.dateTime.month(.abbreviated).day())): ₹\(String(format: "%.0f", amt))")
            } else {
                Text("Total: ₹\(String(format: "%.0f", totalAmount ?? 0))")
            }
        case .month:
            if let selectedDay, let amt = amountOnSelectedDay {
                Text("\(selectedDay.formatted(.dateTime.month(.abbreviated).day())): ₹\(String(format: "%.0f", amt))")
            } else {
                Text("Total: ₹\(String(format: "%.0f", totalAmount ?? 0))")
            }
        case .year:
            if let selectedMonth, let amt = amountOnSelectedMonth {
                Text("\(selectedMonth.formatted(.dateTime.year().month(.abbreviated))): ₹\(String(format: "%.0f", amt))")
            } else {
                Text("Total: ₹\(String(format: "%.0f", totalAmount ?? 0))")
            }
        }
    }

    func fetchSummaryItems(for timeRange: TimeRange) -> [CategorySummary] {
        do {
            var fetchedItems: [CategorySummary] = []
            switch timeRange {
            case .week, .month:
                let dailySummaries = try modelContext.fetch(FetchDescriptor<DailyCategorySummary>())
                fetchedItems = dailySummaries.filter { categories.contains($0.category) }
            case .year:
                let monthlySummaries = try modelContext.fetch(FetchDescriptor<MonthlyCategorySummary>())
                fetchedItems = monthlySummaries.filter { categories.contains($0.category) }
            }
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
