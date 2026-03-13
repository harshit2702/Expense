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
        ScrollView {
            VStack(spacing: 20) {
                // Amount Hero
                VStack(spacing: 6) {
                    Text("₹\(item.amount, specifier: "%.2f")")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text(item.category.displayName)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Details Card
                VStack(spacing: 0) {
                    DetailRow(label: "Date", value: item.date.formatted(.dateTime.year().month(.abbreviated).day()))
                    Divider()
                    DetailRow(label: "Time", value: item.date.formatted(.dateTime.hour().minute()))
                    Divider()
                    DetailRow(label: "Category", value: item.category.displayName)
                    Divider()
                    DetailRow(label: "Payment Method", value: item.paymentMethod?.displayName ?? "Not set")
                    if !item.descriptions.isEmpty {
                        Divider()
                        DetailRow(label: "Description", value: item.descriptions)
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Embedded chart for this category
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spending History")
                        .font(.headline)
                    ChartView(categories: [item.category])
                        .frame(height: 220)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .navigationTitle("Expense Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        ItemInfo(item: Item(id: UUID(), date: Date(), amount: 10.0, descriptions: "Food is an essential aspect of human life.", category: .food))
    }
}
