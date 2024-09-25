//
//  OverView.swift
//  Expense
//
//  Created by Harshit Agarwal on 25/09/24.
//

import SwiftUI
import SwiftData
import Charts

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
    @State private var selectedCategory: String = "None"
    @State private var selectedPrice: Double = 0.0 // Assuming price is a Double

    var body: some View {
        VStack {
            ZStack {
                    Chart(categoryAmount, id: \.category) { entry in
                        SectorMark(
                            angle: .value("Category", entry.amount),
                            innerRadius: .ratio(0.314),
                            angularInset: 2.0
                        )
                        .foregroundStyle(by: .value("Amount", entry.amount))
                    }
                    .chartAngleSelection(value: $selectedCategoryAmount)
                    .padding()
                    
                    VStack {
                        Text("\(String(describing: selectedCategory))")
                        Text("Amount Spend: \(String(format: "%.2f", selectedPrice))")
                    }
                }
            ChartView(categories: [.accommodation,.alcohol])
            
        }
        .onChange(of: selectedCategoryAmount) { newValue in
            if let selectedAmount = newValue {
                print("Selected Amount: \(selectedAmount)")
                if let categoryEntry = categoryAmount.first(where: { $0.cumulativeAmountSt <= selectedAmount && selectedAmount < $0.cumulativeAmountEnd }) {
                    selectedCategory = categoryEntry.category.rawValue
                    selectedPrice = categoryEntry.amount // Assuming amount is the price
                    print("Selected Category: \(selectedCategory ?? "None"), Price: \(selectedPrice)")
                } else {
                    selectedCategory = "None"
                    selectedPrice = 0.0
                    print("No matching category found")
                }
            }
        }
    }
    
}

#Preview {
    OverviewView()
}
