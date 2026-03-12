//
//  DataView.swift
//  Expense
//
//  Created by Harshit Agarwal on 10/08/24.
//

import SwiftUI
import SwiftData
import Charts

enum DataViewSection: String, Identifiable, CaseIterable {
    case overview
    case comparison
    case trends
    case healthScore

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .overview: return "Overview"
        case .comparison: return "Compare Periods"
        case .trends: return "Trends"
        case .healthScore: return "Financial Health"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "chart.pie.fill"
        case .comparison: return "arrow.left.arrow.right"
        case .trends: return "chart.line.uptrend.xyaxis"
        case .healthScore: return "heart.text.square.fill"
        }
    }

    var description: String {
        switch self {
        case .overview: return "Category breakdown, ring chart & spending summary"
        case .comparison: return "Compare two periods side-by-side"
        case .trends: return "Daily patterns, moving average & top categories"
        case .healthScore: return "Your overall financial health score"
        }
    }
}

struct DataView: View {
    var body: some View {
        List {
            ForEach(DataViewSection.allCases) { section in
                NavigationLink(value: section) {
                    HStack(spacing: 14) {
                        Image(systemName: section.icon)
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.displayName)
                                .font(.headline)
                            Text(section.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Analytics")
        .navigationDestination(for: DataViewSection.self) { section in
            destinationView(for: section)
        }
    }

    @ViewBuilder
    private func destinationView(for section: DataViewSection) -> some View {
        switch section {
        case .overview:
            OverviewView()
                .navigationTitle("Overview")
        case .comparison:
            ComparisonView()
                .navigationTitle("Compare")
        case .trends:
            TrendsView()
                .navigationTitle("Trends")
        case .healthScore:
            FinancialHealthView()
                .navigationTitle("Financial Health")
        }
    }
}

#Preview {
    NavigationStack {
        DataView()
    }
}
