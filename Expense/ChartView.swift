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
    @State var category: Categorys = .breakfast
    @State private var selectedTimeRange: TimeRange = .month

    var body: some View {
        let filteredItems = sampleItems.filter { $0.category == category }

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
                Chart(filteredItems) { item in
                    BarMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Amount", item.amount)
                    )
                }
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 3600 * 24 * 7)
                .chartScrollPosition(initialX: Date().addingTimeInterval(7 * 3600 * 24))
            case .month:
                Chart(filteredItems) { item in
                    BarMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Amount", item.amount)
                    )
                }
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 3600 * 24 * 30)
                .chartScrollPosition(initialX: Date().addingTimeInterval(7 * 3600 * 24))
            case .year:
                EmptyView()
            }
        }
        .padding()
    }
}

#Preview {
    ChartView()
}
