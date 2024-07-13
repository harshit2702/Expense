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
        LazyVStack(alignment: .leading, spacing: 10) {
                   Text("ID: \(item.id.uuidString)")
                       .font(.headline)
                   Text("Date: \(item.date, formatter: dateFormatter)")
                        .font(.title)
                   Text("Amount: $\(item.amount, specifier: "%.2f")")
                       .font(.largeTitle)
                   Text("Description: \(item.descriptions)")
                .font(.title)                
                   Text("Category: \(item.category)")
                        .font(.title)
               }
               .padding()
    }
    private var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }
}

#Preview {
    ItemInfo(item: Item(id: UUID(), date: Date(), amount: 10.0, descriptions: "Food is an essential aspect of human life, providing not only the necessary nutrients for survival but also a source of immense pleasure and cultural significance. Across the globe, diverse cuisines reflect the unique traditions, histories, and environments of different regions. From the aromatic spices of Indian curries to the delicate flavors of Japanese sushi, each dish tells a story. Food also serves as a medium for social interaction, bringing people together for shared experiences and celebrations. Beyond its sensory and social pleasures, the importance of food extends to health and well-being, emphasizing the need for balanced diets that support physical and mental health. The culinary arts continue to evolve, integrating new ingredients and techniques while honoring time-honored traditions. ", category: Categorys.food))
}
