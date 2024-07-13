//
//  SwiftUIView.swift
//  Expense
//
//  Created by Harshit Agarwal on 13/07/24.
//

import SwiftUI

struct SwiftUIView: View {
    var body: some View {
        NavigationSplitView {
            Text("Sidebar")
        } content: {
            List(1..<50) { i in
                    NavigationLink("Row \(i)", value: i)
                }
                .navigationDestination(for: Int.self) {
                    Text("Selected row \($0)")
                }
                .navigationTitle("Split View")
        } detail: {
            Text("Detail View")
        }
    }
}

#Preview {
    SwiftUIView()
}
