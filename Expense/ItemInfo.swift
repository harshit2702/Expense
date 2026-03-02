//
//  ItemInfo.swift
//  Expense
//
//  Created by Harshit Agarwal on 06/07/24.
//

import SwiftUI

struct ItemInfo: View {
    @State var item: Item
    var body: some View {
        GeometryReader{geo in
            ScrollView{
                LazyVStack(alignment: .leading, spacing: 10) {
                    HStack{
                        Text("Date: \(item.date, formatter: dateFormatter)")
                            .font(.largeTitle)
                        Spacer()
                        Text("Category: \(item.category)")
                            .font(.largeTitle)
                    }
                    .padding(.vertical)
                    Text("Description: \(item.descriptions)")
                        .font(.title)
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundColor(.blue)
                        .frame(height: 100)
                        .overlay(
                            HStack{
                                Spacer()
                                Text("Amount: \u{20B9}\(item.amount, specifier: "%.2f")")
                                    .font(.largeTitle)
                                Spacer()
                            }
                        )
                        .padding(.vertical)
                }
                .padding()
                .background(Color.yellow.opacity(0.3))
                .border(Color.secondary, width: 5)
                .padding()
                ChartView(categories: [item.category])
                    .frame(width: geo.size.width * 0.9, height: geo.size.height/3)
            }
        }
    }
    private var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }
}

#Preview {
    ItemInfo(item: Item(id: UUID(), date: Date(), amount: 10.0, descriptions: "Food is an essential aspect of human life.", category: .food))
}
