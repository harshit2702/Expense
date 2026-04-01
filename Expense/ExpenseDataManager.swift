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

    // MARK: - Shared Analytics and Budget Metrics

    static func startOfMonth(for date: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    static func currentMonthItems(
        from items: [Item],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [Item] {
        let monthStart = startOfMonth(for: referenceDate, calendar: calendar)
        return items.filter { $0.date >= monthStart }
    }

    static func monthSpend(
        from items: [Item],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Double {
        currentMonthItems(from: items, referenceDate: referenceDate, calendar: calendar)
            .reduce(0) { $0 + $1.amount }
    }

    static func monthSpendByCategory(
        from items: [Item],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [ExpenseCategory: Double] {
        let monthItems = currentMonthItems(from: items, referenceDate: referenceDate, calendar: calendar)
        return monthItems.reduce(into: [ExpenseCategory: Double]()) { partialResult, item in
            partialResult[item.category, default: 0] += item.amount
        }
    }

    static func categoryBudgetTotal(from budgets: [Budget]) -> Double {
        budgets.reduce(0) { $0 + $1.monthlyLimit }
    }

    static func budgetedCategorySpend(
        from items: [Item],
        budgets: [Budget],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Double {
        let spendByCategory = monthSpendByCategory(from: items, referenceDate: referenceDate, calendar: calendar)
        return budgets.reduce(0) { partialResult, budget in
            partialResult + (spendByCategory[budget.category] ?? 0)
        }
    }

    static func monthlyBudgetUsagePercent(
        monthlyTotalBudget: Double?,
        items: [Item],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Double {
        guard let monthlyTotalBudget, monthlyTotalBudget > 0 else { return 0 }
        let spent = monthSpend(from: items, referenceDate: referenceDate, calendar: calendar)
        return (spent / monthlyTotalBudget) * 100
    }

    static func daysRemainingInMonth(from date: Date = Date(), calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: date)
        guard let range = calendar.range(of: .day, in: .month, for: today) else { return 0 }
        let currentDay = calendar.component(.day, from: today)
        let lastDay = range.upperBound - 1
        return max(lastDay - currentDay, 0)
    }
}
