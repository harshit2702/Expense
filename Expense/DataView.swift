//
//  DataView.swift
//  Expense
//
//  Created by Harshit Agarwal on 10/08/24.
//

import SwiftUI
import SwiftData
import Charts

enum DataViewSection:String, Identifiable, CaseIterable {
    case overview
    case comparison
    case trends
    
    var id: String { self.rawValue }
}

struct DataView: View {
    @State private var selectedDataViewSection: DataViewSection? = .overview

    var body: some View {
        NavigationView {
            List(DataViewSection.allCases, id: \.self, selection: $selectedDataViewSection) { section in
                NavigationLink(destination: destinationView(for: section)) {
                    SidebarLabel(label: section.rawValue, isSelected: .constant(selectedDataViewSection == section))
                }
            }
            .navigationTitle("Data Analysis")
        }
    }

    @ViewBuilder
    private func destinationView(for section: DataViewSection) -> some View {
        switch section {
        case .overview:
            OverviewView()
        case .comparison:
            ComparisonView()
        case .trends:
            TrendsView()
        }
    }
}


// Placeholder views for each section
struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    
    var categoryAmount: [(category: Categorys, amount: Double, cumulativeAmountSt: Double, cumulativeAmountEnd: Double)] {
           let amountDict = sampleItems.reduce(into: [Categorys: Double]()) { result, item in
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
    @State private var selectedCategory: String?

    var body: some View {
        VStack {
            Text("\(String(describing: selectedCategory))")
            Chart(categoryAmount, id: \.category) { entry in
                SectorMark(
                    angle: .value("Category", entry.amount),
                    innerRadius: .ratio(0.314),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Amount", entry.amount))
            }
            .chartAngleSelection(value: $selectedCategoryAmount)
            .padding()
        }
        .onChange(of: selectedCategoryAmount) { newValue in
                if let selectedAmount = newValue {
                    if let category = categoryAmount.first(where: { $0.cumulativeAmountSt <= selectedAmount && selectedAmount < $0.cumulativeAmountEnd })?.category {
                        selectedCategory = category.rawValue
                    } else {
                        selectedCategory = "None"
                    }
                }
            }
    }
    
}

struct ComparisonView: View {
    var body: some View {
        Text("Comparison")
    }
}

struct TrendsView: View {
    var body: some View {
        Text("Trends")
    }
}

#Preview {
    DataView()
}
