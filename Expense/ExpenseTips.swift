//
//  ExpenseTips.swift
//  Expense
//
//  TipKit tips for onboarding and feature discovery.
//  iOS 17+
//

import TipKit

// MARK: - Entry Tips

/// Shown on the Add button when user has no expenses yet.
struct AddExpenseTip: Tip {
    var title: Text { Text("Add Your First Expense") }
    var message: Text? { Text("Tap the + button to log a new expense with category, amount, and description.") }
    var image: Image? { Image(systemName: "plus.circle.fill") }
    
    @Parameter
    static var hasAddedExpense: Bool = false
    
    var rules: [Rule] {
        [
            #Rule(Self.$hasAddedExpense) { $0 == false }
        ]
    }
}

/// Shown near the search bar the first time EntryView appears with items.
struct SearchExpensesTip: Tip {
    var title: Text { Text("Search Expenses") }
    var message: Text? { Text("Use the search bar to quickly find expenses by category, description, or amount.") }
    var image: Image? { Image(systemName: "magnifyingglass") }
    
    @Parameter
    static var hasSearched: Bool = false
    
    var rules: [Rule] {
        [
            #Rule(Self.$hasSearched) { $0 == false }
        ]
    }
}

// MARK: - Budget Tips

/// Shown the first time user visits the Budget section.
struct SetBudgetTip: Tip {
    var title: Text { Text("Set a Budget") }
    var message: Text? { Text("Set monthly spending limits per category to keep your finances on track.") }
    var image: Image? { Image(systemName: "target") }
    
    @Parameter
    static var hasBudget: Bool = false
    
    var rules: [Rule] {
        [
            #Rule(Self.$hasBudget) { $0 == false }
        ]
    }
}

// MARK: - Data & Trends Tips

/// Shown the first time user visits the Trends view.
struct ViewTrendsTip: Tip {
    var title: Text { Text("Explore Spending Trends") }
    var message: Text? { Text("See your daily spending patterns, 7-day moving average, and top categories at a glance.") }
    var image: Image? { Image(systemName: "chart.line.uptrend.xyaxis") }

    @Parameter
    static var hasViewedTrends: Bool = false

    var rules: [Rule] {
        [
            #Rule(Self.$hasViewedTrends) { $0 == false }
        ]
    }
}

/// Shown when user first visits the Comparison view.
struct CompareSpendingTip: Tip {
    var title: Text { Text("Compare Periods") }
    var message: Text? { Text("Select two date ranges to compare spending side-by-side and spot changes.") }
    var image: Image? { Image(systemName: "arrow.left.arrow.right") }

    @Parameter
    static var hasCompared: Bool = false

    var rules: [Rule] {
        [
            #Rule(Self.$hasCompared) { $0 == false }
        ]
    }
}

// MARK: - Overview Tip

/// Shown the first time user opens the pie chart overview.
struct OverviewTip: Tip {
    var title: Text { Text("Visual Overview") }
    var message: Text? { Text("Tap a pie chart segment to see spending details for that category.") }
    var image: Image? { Image(systemName: "chart.pie.fill") }

    @Parameter
    static var hasViewedOverview: Bool = false

    var rules: [Rule] {
        [
            #Rule(Self.$hasViewedOverview) { $0 == false }
        ]
    }
}
