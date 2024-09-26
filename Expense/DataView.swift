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
