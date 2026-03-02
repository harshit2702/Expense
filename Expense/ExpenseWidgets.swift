//
//  ExpenseWidgets.swift
//  Expense
//
//  Control Center Widget & Home Screen Widget for quick expense overview.
//
//  NOTE: To use this file, you must add a Widget Extension target in Xcode:
//    1. File → New → Target → Widget Extension
//    2. Name it "ExpenseWidget"
//    3. Move this file into the new widget target
//    4. Ensure the widget target has access to the shared SwiftData models
//       (add Item.swift, ExpenseDataManager.swift to the widget target, or
//        create a shared framework)
//    5. Add an App Group for shared data between app and widget
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Provider

struct ExpenseTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExpenseWidgetEntry {
        ExpenseWidgetEntry(date: Date(), todayTotal: 0, weekTotal: 0, topCategory: "Food")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ExpenseWidgetEntry) -> Void) {
        let entry = ExpenseWidgetEntry(date: Date(), todayTotal: 250, weekTotal: 1750, topCategory: "Food")
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ExpenseWidgetEntry>) -> Void) {
        // In production, fetch from shared SwiftData container via App Group
        let entry = ExpenseWidgetEntry(date: Date(), todayTotal: 0, weekTotal: 0, topCategory: "—")
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Entry

struct ExpenseWidgetEntry: TimelineEntry {
    let date: Date
    let todayTotal: Double
    let weekTotal: Double
    let topCategory: String
}

// MARK: - Widget Views

struct ExpenseWidgetSmallView: View {
    var entry: ExpenseWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "indianrupeesign.circle.fill")
                    .foregroundStyle(.blue)
                Text("Expenses")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("₹\(String(format: "%.0f", entry.todayTotal))")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text("This week: ₹\(String(format: "%.0f", entry.weekTotal))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

struct ExpenseWidgetMediumView: View {
    var entry: ExpenseWidgetEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "indianrupeesign.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Expense Tracker")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Spending")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("₹\(String(format: "%.0f", entry.todayTotal))")
                        .font(.title)
                        .fontWeight(.bold)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("This Week")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("₹\(String(format: "%.0f", entry.weekTotal))")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Top Category")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.topCategory)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

// MARK: - Widget Configuration

struct ExpenseHomeWidget: Widget {
    let kind = "ExpenseHomeWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExpenseTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                ExpenseWidgetSmallView(entry: entry)
            } else {
                ExpenseWidgetSmallView(entry: entry)
                    .padding()
            }
        }
        .configurationDisplayName("Expense Tracker")
        .description("Quick view of today's spending.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Control Center Widget (iOS 18+)
// Uncomment when targeting iOS 18+ with ControlWidget API
/*
@available(iOS 18.0, *)
struct ExpenseControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ExpenseControlWidget") {
            ControlWidgetButton(action: OpenExpenseIntent()) {
                Label("Add Expense", systemImage: "plus.circle.fill")
                Text("₹0 today")
            }
        }
        .displayName("Quick Add Expense")
        .description("Quickly add a new expense.")
    }
}
*/

// MARK: - Widget Bundle

// When using a Widget Extension target, replace @main in the widget target with:
/*
@main
struct ExpenseWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExpenseHomeWidget()
        // ExpenseControlWidget() // iOS 18+
    }
}
*/

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    ExpenseHomeWidget()
} timeline: {
    ExpenseWidgetEntry(date: Date(), todayTotal: 450, weekTotal: 2100, topCategory: "Food")
}

#Preview("Medium", as: .systemMedium) {
    ExpenseHomeWidget()
} timeline: {
    ExpenseWidgetEntry(date: Date(), todayTotal: 450, weekTotal: 2100, topCategory: "Groceries")
}
