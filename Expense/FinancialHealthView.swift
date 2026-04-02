//
//  FinancialHealthView.swift
//  Expense
//
//  Single-score financial health dashboard.
//  Score is 0–100 based on budget adherence, spend stability,
//  and month-over-month change.
//

import SwiftUI
import SwiftData
import Charts

struct FinancialHealthView: View {
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    @Query private var budgets: [Budget]

    // MARK: - Score Components

    /// Budget adherence score (0–40 pts)
    private var budgetAdherenceScore: Double {
        guard !budgets.isEmpty else { return 20 } // neutral if no budgets
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())!.start
        var totalUsedPct: Double = 0
        for budget in budgets {
            let spent = items.filter { $0.category == budget.category && $0.date >= startOfMonth }.reduce(0) { $0 + $1.amount }
            let pct = budget.monthlyLimit > 0 ? spent / budget.monthlyLimit : 1
            totalUsedPct += min(pct, 2) // cap at 2x
        }
        let avgUsedPct = totalUsedPct / Double(budgets.count)
        // 0% used = 40, 100% = 20, 200% = 0
        return max(0, min(40, 40 * (1 - (avgUsedPct - 0.5))))
    }

    /// Spend volatility score (0–30 pts) — lower daily variance is better
    private var stabilityScore: Double {
        let cal = Calendar.current
        let thirtyDaysAgo = cal.date(byAdding: .day, value: -29, to: Date())!
        let recent = items.filter { $0.date >= thirtyDaysAgo }
        let grouped = Dictionary(grouping: recent) { cal.startOfDay(for: $0.date) }
        let dailyTotals = grouped.values.map { $0.reduce(0) { $0 + $1.amount } }

        guard dailyTotals.count >= 2 else { return 15 }

        let mean = dailyTotals.reduce(0, +) / Double(dailyTotals.count)
        guard mean > 0 else { return 30 }
        let variance = dailyTotals.reduce(0) { $0 + pow($1 - mean, 2) } / Double(dailyTotals.count)
        let cv = sqrt(variance) / mean // coefficient of variation

        // cv < 0.3 = 30pts, cv > 1.5 = 0pts
        return max(0, min(30, 30 * (1 - (cv - 0.3) / 1.2)))
    }

    /// Month-over-month change score (0–30 pts) — spending less = better
    private var momScore: Double {
        let cal = Calendar.current
        let startOfMonth = cal.dateInterval(of: .month, for: Date())!.start
        let startOfLastMonth = cal.date(byAdding: .month, value: -1, to: startOfMonth)!

        let thisMonth = items.filter { $0.date >= startOfMonth }.reduce(0) { $0 + $1.amount }
        let lastMonth = items.filter { $0.date >= startOfLastMonth && $0.date < startOfMonth }.reduce(0) { $0 + $1.amount }

        guard lastMonth > 0 else { return 15 }
        let change = (thisMonth - lastMonth) / lastMonth
        // -50% = 30pts, 0% = 15pts, +50% = 0pts
        return max(0, min(30, 15 * (1 - change)))
    }

    private var totalScore: Int {
        Int(round(budgetAdherenceScore + stabilityScore + momScore))
    }

    private var scoreLabel: String {
        switch totalScore {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        case 20..<40: return "Needs attention"
        default: return "Critical"
        }
    }

    private var scoreColor: Color {
        switch totalScore {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .yellow
        case 20..<40: return .orange
        default: return .red
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Score Ring
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: Double(totalScore) / 100)
                        .stroke(scoreColor.gradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1), value: totalScore)
                    VStack(spacing: 4) {
                        Text("\(totalScore)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                        Text(scoreLabel)
                            .font(.headline)
                            .foregroundStyle(scoreColor)
                    }
                }
                .frame(width: 180, height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Financial health score")
                .accessibilityValue("\(totalScore) out of 100, \(scoreLabel)")

                // Breakdown
                CardSurface {
                    VStack(spacing: 12) {
                        ScoreBreakdownRow(label: "Budget Adherence", score: Int(round(budgetAdherenceScore)), maxScore: 40,
                                          color: budgetAdherenceScore > 25 ? .green : budgetAdherenceScore > 15 ? .orange : .red)
                        ScoreBreakdownRow(label: "Spend Stability", score: Int(round(stabilityScore)), maxScore: 30,
                                          color: stabilityScore > 20 ? .green : stabilityScore > 10 ? .orange : .red)
                        ScoreBreakdownRow(label: "Month vs Last Month", score: Int(round(momScore)), maxScore: 30,
                                          color: momScore > 20 ? .green : momScore > 10 ? .orange : .red)
                    }
                }

                // Recommendations
                CardSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommendations")
                            .font(.headline)

                        ForEach(recommendations, id: \.text) { rec in
                            InsightRow(icon: rec.icon, color: rec.color, text: rec.text, detail: rec.detail)
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Recommendations

    private var recommendations: [(icon: String, color: Color, text: String, detail: String)] {
        var recs: [(icon: String, color: Color, text: String, detail: String)] = []

        if budgetAdherenceScore < 20 {
            recs.append((icon: "target", color: .red,
                         text: "Review your budgets",
                         detail: "Several categories are over budget — consider adjusting limits or reducing spending"))
        }
        if stabilityScore < 15 {
            recs.append((icon: "waveform.path.ecg", color: .orange,
                         text: "Spending is inconsistent",
                         detail: "Large daily swings make it hard to plan — try spreading purchases more evenly"))
        }
        if momScore < 10 {
            recs.append((icon: "arrow.up.right", color: .red,
                         text: "Spending increased significantly",
                         detail: "This month is much higher than last — identify which categories grew"))
        }
        if totalScore >= 70 {
            recs.append((icon: "star.fill", color: .green,
                         text: "You're doing well!",
                         detail: "Maintain current habits and consider setting savings goals"))
        }
        if budgets.isEmpty {
            recs.append((icon: "plus.circle.fill", color: .blue,
                         text: "Set category budgets",
                         detail: "Budgets give you guardrails and improve your health score"))
        }
        return recs
    }
}

// MARK: - Score Breakdown Row

struct ScoreBreakdownRow: View {
    let label: String
    let score: Int
    let maxScore: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(score)/\(maxScore)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            ProgressView(value: Double(score), total: Double(maxScore))
                .tint(color)
        }
    }
}

#Preview {
    NavigationStack {
        FinancialHealthView()
            .navigationTitle("Financial Health")
    }
    .modelContainer(for: [Item.self, Budget.self], inMemory: true)
}
