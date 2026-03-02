//
//  ExpenseDataManager.swift
//  Expense
//
//  Shared helper that consolidates data mutation logic used across views.
//

import Foundation
import SwiftData

struct ExpenseDataManager {
    static func addItemAndUpdateSummaries(
        item: Item,
        dailySummaries: [DailyCategorySummary],
        monthlySummaries: [MonthlyCategorySummary],
        context: ModelContext
    ) {
        context.insert(item)

        let date = item.date
        let amount = item.amount
        let category = item.category
        let startOfDay = Calendar.current.startOfDay(for: date)

        // Daily Summary
        if let dailySummary = dailySummaries.first(where: { $0.date == startOfDay && $0.category == category }) {
            dailySummary.totalAmount += amount
        } else {
            let newDailySummary = DailyCategorySummary(category: category, date: startOfDay, totalAmount: amount)
            context.insert(newDailySummary)
        }

        // Monthly Summary
        if let startOfMonth = Calendar.current.dateInterval(of: .month, for: date)?.start {
            if let monthlySummary = monthlySummaries.first(where: { $0.date == startOfMonth && $0.category == category }) {
                monthlySummary.totalAmount += amount
            } else {
                let newMonthlySummary = MonthlyCategorySummary(category: category, date: startOfMonth, totalAmount: amount)
                context.insert(newMonthlySummary)
            }
        }

        do {
            try context.save()
        } catch {
            print("Failed to save data: \(error)")
        }
    }

    static func deleteItemAndUpdateSummaries(
        item: Item,
        dailySummaries: [DailyCategorySummary],
        monthlySummaries: [MonthlyCategorySummary],
        context: ModelContext
    ) {
        let date = item.date
        let category = item.category
        let amount = item.amount

        context.delete(item)

        // Update Daily Summary
        let startOfDay = Calendar.current.startOfDay(for: date)
        if let dailySummary = dailySummaries.first(where: { $0.date == startOfDay && $0.category == category }) {
            dailySummary.totalAmount -= amount
            if dailySummary.totalAmount <= 0 {
                context.delete(dailySummary)
            }
        }

        // Update Monthly Summary
        if let startOfMonth = Calendar.current.dateInterval(of: .month, for: date)?.start {
            if let monthlySummary = monthlySummaries.first(where: { $0.date == startOfMonth && $0.category == category }) {
                monthlySummary.totalAmount -= amount
                if monthlySummary.totalAmount <= 0 {
                    context.delete(monthlySummary)
                }
            }
        }

        do {
            try context.save()
        } catch {
            print("Failed to save data: \(error)")
        }
    }

    static func deleteAllData(
        items: [Item],
        dailySummaries: [DailyCategorySummary],
        monthlySummaries: [MonthlyCategorySummary],
        context: ModelContext
    ) {
        for item in items { context.delete(item) }
        for summary in dailySummaries { context.delete(summary) }
        for summary in monthlySummaries { context.delete(summary) }

        do {
            try context.save()
        } catch {
            print("Failed to save data: \(error)")
        }
    }
}
