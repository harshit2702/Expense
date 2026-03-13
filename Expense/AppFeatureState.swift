import SwiftUI

enum RegularAppTab: Hashable {
    case home
    case entries
    case analytics
    case budget
    case about
}

final class AppCommandCenter: ObservableObject {
    @Published var requestedTab: RegularAppTab = .home

    @Published var addExpenseCommandTick = 0
    @Published var importCSVCommandTick = 0
    @Published var focusSearchCommandTick = 0
    @Published var editSelectedCommandTick = 0
    @Published var deleteSelectedCommandTick = 0

    @Published var selectedEntryID: UUID?

    func goToTab(_ tab: RegularAppTab) {
        requestedTab = tab
    }

    func triggerAddExpense() {
        addExpenseCommandTick += 1
    }

    func triggerImportCSV() {
        importCSVCommandTick += 1
    }

    func triggerFocusSearch() {
        focusSearchCommandTick += 1
    }

    func triggerEditSelected() {
        editSelectedCommandTick += 1
    }

    func triggerDeleteSelected() {
        deleteSelectedCommandTick += 1
    }
}

struct AnalyticsFilterOptions: Equatable {
    var category: ExpenseCategory?
    var paymentMethod: PaymentMethod?
}

private struct AnalyticsFilterOptionsKey: EnvironmentKey {
    static let defaultValue = AnalyticsFilterOptions(category: nil, paymentMethod: nil)
}

extension EnvironmentValues {
    var analyticsFilterOptions: AnalyticsFilterOptions {
        get { self[AnalyticsFilterOptionsKey.self] }
        set { self[AnalyticsFilterOptionsKey.self] = newValue }
    }
}
