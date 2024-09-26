//
//  ChartView.swift
//  Expense
//
//  Created by Harshit Agarwal on 15/07/24.
//

import SwiftUI
import SwiftData
import Charts

enum TimeRange:String, CaseIterable, Identifiable{
    case week,month,year
    
    var id: String { self.rawValue }
}

struct ChartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    @State var categories: [Categorys] = [.food]
    @State private var selectedTimeRange: TimeRange = .month
    @State var selectedDay: Date?
    @State var scrollPosition: Date = Date()
    @State var amountOnSelectedDay: Double?
    @State var totalAmount: Double?
    @State var selectedMonth: Date?
    @State var amountOnSelectedMonth: Double?


    var body: some View {
        @State var filteredItems = items.filter { categories.contains($0.category) }
        GeometryReader{ geo in
            
            HStack{
                VStack{
                    switch selectedTimeRange                     {
                        case .week:
                            if let selectedDay = selectedDay {
                                Text("On \(selectedDay.formatted(.dateTime.year(.twoDigits).month(.abbreviated).day())) the amount spent is \(amountOnSelectedDay ?? 0.0, specifier: "%.2f")")
                            } else {
                                Text("Total Amount \(totalAmount ?? 0.0, specifier: "%.2f") during")
                            }
                        Text("\(scrollPosition.formatted(.dateTime.month(.abbreviated).day()))-\(scrollPosition.addingTimeInterval(6 * 3600 * 24).formatted(.dateTime.year(.twoDigits).month(.abbreviated).day()))")
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
                
                VStack{
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
                        WeekChartView(items: $filteredItems, selectedDay: $selectedDay, scrollPosition: $scrollPosition, amountOnSelectedDay: $amountOnSelectedDay, totalAmount: $totalAmount)
                    case .month:
                        MonthChartView(items: $filteredItems, selectedDay: $selectedDay, scrollPosition: $scrollPosition, amountOnSelectedDay: $amountOnSelectedDay, totalAmount: $totalAmount)
                    case .year:
                        YearChartView(items: $filteredItems, selectedMonth: $selectedMonth, scrollPosition: $scrollPosition, amountOnSelectedMonth: $amountOnSelectedMonth, totalAmount: $totalAmount)
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    ChartView(scrollPosition: Date())
}
