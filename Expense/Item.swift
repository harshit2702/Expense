//
//  Item.swift
//  Expense
//
//  Created by Harshit Agarwal on 06/07/24.
//

import Foundation
import SwiftData

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable, Comparable {
    case food
    case transport
    case breakfast
    case lunch
    case dinner
    case groceries
    case utilities
    case rent
    case mortgage
    case insurance
    case healthcare
    case entertainment
    case education
    case investment
    case savings
    case clothing
    case personalCare
    case subscriptions
    case gifts
    case charity
    case fitness
    case pets
    case householdSupplies
    case childcare
    case debtRepayment
    case electronics
    case coffee
    case snacks
    case alcohol
    case parking
    case taxi
    case publicTransport
    case carMaintenance
    case fuel
    case books
    case hobbies
    case music
    case movies
    case theater
    case concerts
    case sportingEvents
    case vacation
    case flights
    case shopping
    case homeImprovement
    case gardening
    case furniture
    case decorations
    case internet
    case phone
    case cable
    case creditCard
    case businessExpenses
    case legalFees
    case bankingFees
    case taxes
    case fines
    case miscellaneous
    
    var id: String { self.rawValue }
    
    var displayName: String {
        rawValue
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }

    /// Compact list shown by default in the Add Expense picker.
    /// The full `allCases` list remains available via "Show all categories".
    /// Merges:  breakfast/lunch/dinner → food  |  taxi/publicTransport/fuel/parking → transport
    ///          movies/music/theater/concerts/sportingEvents → entertainment
    ///          internet/phone/cable → utilities  |  gardening/furniture/decorations → homeImprovement
    ///          creditCard/bankingFees/debtRepayment moved to PaymentMethod
    static var primaryCases: [ExpenseCategory] {
        [
            .food,
            .groceries,
            .transport,
            .utilities,
            .rent,
            .entertainment,
            .healthcare,
            .education,
            .shopping,
            .subscriptions,
            .homeImprovement,
            .personalCare,
            .investment,
            .savings,
            .gifts,
            .charity,
            .childcare,
            .pets,
            .miscellaneous
        ]
    }
    
    static func < (lhs: ExpenseCategory, rhs: ExpenseCategory) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable, Comparable {
    case cash
    case debitCard
    case creditCard
    case upi
    case wallet
    case other

    var id: String { rawValue }

    var displayName: String {
        rawValue
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }

    static func < (lhs: PaymentMethod, rhs: PaymentMethod) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum PaymentMethodFilter: String, CaseIterable, Identifiable {
    case all
    case notSet
    case cash
    case debitCard
    case creditCard
    case upi
    case wallet
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return "All Methods"
        case .notSet:
            return "Not Set"
        default:
            return PaymentMethod(rawValue: rawValue)?.displayName ?? rawValue.capitalized
        }
    }

    var method: PaymentMethod? {
        PaymentMethod(rawValue: rawValue)
    }
}


@Model
final class Item: Identifiable, Hashable {
    var id: UUID
    var date: Date
    var amount: Double
    var descriptions: String
    var category: ExpenseCategory
    var paymentMethod: PaymentMethod?
    
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        amount: Double = 10.0,
        descriptions: String = "Text",
        category: ExpenseCategory = .breakfast,
        paymentMethod: PaymentMethod? = .upi
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.descriptions = descriptions
        self.category = category
        self.paymentMethod = paymentMethod
    }
}

protocol CategorySummary {
    var category: ExpenseCategory { get }
    var date: Date { get }
    var totalAmount: Double { get }
}

@Model
final class DailyCategorySummary: CategorySummary {
    var category: ExpenseCategory
    var date: Date
    var totalAmount: Double
    
    init(category: ExpenseCategory, date: Date, totalAmount: Double) {
        self.category = category
        self.date = date
        self.totalAmount = totalAmount
    }
}

@Model
final class MonthlyCategorySummary: CategorySummary {
    var category: ExpenseCategory
    var date: Date
    var totalAmount: Double
    
    init(category: ExpenseCategory, date: Date, totalAmount: Double) {
        self.category = category
        self.date = date
        self.totalAmount = totalAmount
    }
}


//Sample Data

// Helper function to generate dates separated by one day
func generateDates(count: Int, startingFrom startDate: Date) -> [Date] {
    var dates: [Date] = []
    var currentDate = startDate
    for _ in 0..<count {
        dates.append(currentDate)
        currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
    }
    return dates
}

// Generate a sample dataset of items
let categories: [ExpenseCategory] = [
    .breakfast, .groceries, .publicTransport, .rent, .insurance, .entertainment,
    .carMaintenance, .books, .snacks, .flights, .internet, .fitness,
    .taxi, .coffee, .personalCare, .clothing, .phone, .investment, .charity
]

let descriptions: [String] = [
    "Breakfast at cafe", "Grocery shopping", "Bus ticket", "Monthly rent", "Health insurance",
    "Movie night", "Car maintenance", "New book", "Snacks", "Vacation flight",
    "Home internet bill", "Fitness club membership", "Dinner out", "Taxi ride",
    "Morning coffee", "Haircut", "New clothes", "Monthly phone bill", "Investment in stocks",
    "Charity donation"
]

let dates = generateDates(count: 100, startingFrom: Date())

let sampleItems: [Item] = dates.map { date in
    let randomCategory = categories.randomElement()!
    let randomDescription = descriptions.randomElement()!
    return Item(date: date, amount: Double(Int.random(in: 5...200)), descriptions: randomDescription, category: randomCategory)
}


// MARK: - Budget Model

@Model
final class Budget: Identifiable {
    var id: UUID
    var category: ExpenseCategory
    var monthlyLimit: Double
    var createdDate: Date
    
    init(id: UUID = UUID(), category: ExpenseCategory, monthlyLimit: Double, createdDate: Date = Date()) {
        self.id = id
        self.category = category
        self.monthlyLimit = monthlyLimit
        self.createdDate = createdDate
    }
}

@Model
final class MonthlyBudgetSettings: Identifiable {
    var id: UUID
    var monthlyTotalBudget: Double?
    var updatedAt: Date

    init(id: UUID = UUID(), monthlyTotalBudget: Double? = nil, updatedAt: Date = Date()) {
        self.id = id
        self.monthlyTotalBudget = monthlyTotalBudget
        self.updatedAt = updatedAt
    }
}

