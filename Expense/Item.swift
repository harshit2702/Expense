//
//  Item.swift
//  Expense
//
//  Created by Harshit Agarwal on 06/07/24.
//

import Foundation
import SwiftData

enum Categorys: String, Codable, CaseIterable, Identifiable,Comparable {
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
    case travel
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
    case diningOut
    case coffee
    case snacks
    case alcohol
    case transportation
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
    case accommodation
    case tours
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
    
    var id: String { self.rawValue}
    
    static func < (lhs: Categorys, rhs: Categorys) -> Bool {
           return lhs.rawValue < rhs.rawValue
       }
}


@Model
final class Item: Identifiable, Hashable {
    var id: UUID
    var date: Date
    var amount: Double
    var descriptions: String
    var category: Categorys
    
    
    init(id: UUID = UUID(), date: Date = Date(), amount: Double = 10.0, descriptions: String = "Text", category: Categorys = Categorys.breakfast) {
        self.id = id
        self.date = date
        self.amount = amount
        self.descriptions = descriptions
        self.category = category
    }
}

protocol CategorySummary {
    var category: Categorys { get }
    var date: Date { get }
    var totalAmount: Double { get }
}

@Model
final class DailyCategorySummary: CategorySummary {
    var category: Categorys
    var date: Date // Store only the day, with time set to 00:00
    var totalAmount: Double
    
    init(category: Categorys, date: Date, totalAmount: Double) {
        self.category = category
        self.date = date
        self.totalAmount = totalAmount
    }
}

@Model
final class MonthlyCategorySummary: CategorySummary {
    var category: Categorys
    var date: Date // Store only the day, with time set to 00:00
    var totalAmount: Double
    
    init(category: Categorys, date: Date, totalAmount: Double) {
        self.category = category
        self.date = date
        self.totalAmount = totalAmount
    }
}

@Model
final class YearlyCategorySummary: CategorySummary {
    
    var category: Categorys
    var date: Date // Store the start of the year (e.g., Jan 1st)
    var totalAmount: Double
    
    init(category: Categorys, date: Date, totalAmount: Double) {
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
let categories: [Categorys] = [
    .breakfast
//    , .groceries, .publicTransport, .rent, .insurance, .entertainment,
//    .carMaintenance, .books, .snacks, .flights, .internet, .fitness, .diningOut,
//    .taxi, .coffee, .personalCare, .clothing, .phone, .investment, .charity
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



