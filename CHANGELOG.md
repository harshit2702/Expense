# Expense Tracker — Project Log

## Project Overview

**App Name:** Expense  
**Platform:** iOS / iPadOS / macOS (SwiftUI)  
**Started:** July 6, 2024  
**Author:** Harshit Agarwal  
**Stack:** SwiftUI, SwiftData, Swift Charts  

---

## Initial State (Pre-Cleanup — as of March 1, 2026)

### Architecture

- **No MVVM** — all business logic lived directly inside SwiftUI views
- **Data layer:** SwiftData with 3 models:
  - `Item` — individual expense entries (id, date, amount, description, category)
  - `DailyCategorySummary` — pre-aggregated daily totals per category
  - `MonthlyCategorySummary` — pre-aggregated monthly totals per category
- **Categories:** 60+ expense categories defined in a `Categorys` enum (with typo in name)
- **Views:**
  - `ContentView` — main NavigationSplitView with sidebar sections (Entry, Overview, Data, About Us)
  - `EntryView` — lists all expense Items, supports add/delete/delete-all
  - `AddView` — form for creating a new expense (amount, description, category picker, date)
  - `ItemInfo` — detail view for a single expense Item with an embedded chart
  - `OverviewView` — pie chart + bar charts for spending overview
  - `DataView` — sub-navigation with Overview, Comparison (stub), Trends (stub)
  - `ChartView` — wrapper that switches between Week/Month/Year charts
  - `WeekChartView`, `MonthChartView`, `YearChartView` — scrollable bar charts using Swift Charts
  - `SwiftUIView` — unused test/scaffold file (dead code)

### Bugs & Issues Found

| # | Issue | File(s) | Severity |
|---|---|---|---|
| 1 | `@State var` declared **inside** `body` — not valid SwiftUI; state would reset every render | MonthChartView, WeekChartView, YearChartView | 🔴 Critical |
| 2 | `print()` statement inside view `body` — causes side effects during rendering | MonthChartView | 🟡 Medium |
| 3 | Summary update logic (daily/monthly add + delete) **copy-pasted** in 3 places | AddView, ContentView (addItem, deleteItems, deleteAllItems) | 🟡 Medium |
| 4 | Pie chart colored by amount value instead of category name — all same-value categories get same color | OverView | 🟡 Medium |
| 5 | Typo `"Discription"` in placeholder text | AddView | 🟢 Low |
| 6 | Currency mismatch: `"INR"` in entry list vs `"$"` in ItemInfo detail | ContentView, ItemInfo | 🟡 Medium |
| 7 | `deleteAllItems()` calls `modelContext.save()` inside a loop — N saves instead of 1 | ContentView | 🟡 Medium |
| 8 | Deprecated `.onChange(of:) { _ in }` closure syntax (iOS 16 style, deprecated since iOS 17) | OverView, MonthChartView, WeekChartView, YearChartView | 🟡 Medium |
| 9 | `SwiftUIView.swift` — unused dead code file | SwiftUIView | 🟢 Low |
| 10 | No form validation — amount can be empty or zero | AddView | 🟡 Medium |
| 11 | `String(describing:)` used unnecessarily on selectedCategory string | OverView | 🟢 Low |
| 12 | Typo `"Amount Spend"` instead of `"Amount Spent"` | OverView | 🟢 Low |

### Missing Features (Not Yet Implemented)

- iPhone-optimized layout (current design is iPad/macOS–oriented)
- Comparison view (stub only)
- Trends view (stub only)  
- About Us section (placeholder text only)
- Search or filter on entries list
- Recurring expenses
- Budget per category / spending limits
- Data export (CSV/PDF)
- WidgetKit widgets
- App Intents / Siri Shortcuts
- CloudKit sync
- Onboarding / empty states
- Dark mode–optimized custom colors
- Haptic feedback
- Localization

---

## Phase 1 — Bug Fixes & Code Quality (March 1, 2026)

### Changes Made

#### 1. Fixed `@State` inside `body` in all chart views
**Files:** `MonthChartView.swift`, `WeekChartView.swift`, `YearChartView.swift`  
**What:** `@State var dailyItems` and `@State var mostRecentDate` were declared inside the `body` computed property. This meant SwiftUI couldn't properly manage the state — it would be re-created on every view update instead of persisting.  
**Fix:** Converted to computed properties (`private var dailyItems`, `private var mostRecentDate`) and moved helper functions (`calculateTotalAmount`) to struct-level methods. Removed the `return` keyword since `body` now has a single expression.

#### 2. Removed `print()` from view body
**File:** `MonthChartView.swift`  
**What:** `print("Month Chart Items: \(items)")` was called inside `body`, which is a side effect during rendering. This fires on every re-render and clutters console output.  
**Fix:** Removed entirely. Debug logging should use `onAppear` or breakpoints, not inline `body` statements.

#### 3. Extracted summary update logic into `ExpenseDataManager`
**File Created:** `ExpenseDataManager.swift`  
**Files Modified:** `AddView.swift`, `ContentView.swift`  
**What:** The same logic for updating `DailyCategorySummary` and `MonthlyCategorySummary` was copy-pasted in 3 places (AddView save button, EntryView addItem, EntryView deleteItems). Any bug fix needed to be applied 3 times.  
**Fix:** Created `ExpenseDataManager` with static methods:
- `addItemAndUpdateSummaries(item:dailySummaries:monthlySummaries:context:)`
- `deleteItemAndUpdateSummaries(item:dailySummaries:monthlySummaries:context:)`
- `deleteAllData(items:dailySummaries:monthlySummaries:context:)`
All views now call through this single source of truth.

#### 4. Fixed pie chart coloring
**File:** `OverView.swift`  
**What:** `.foregroundStyle(by: .value("Amount", entry.amount))` colored chart sectors by their numeric amount. Multiple categories with similar totals would get the same color.  
**Fix:** Changed to `.foregroundStyle(by: .value("Category", entry.category.rawValue.capitalized))` so each category gets a unique color.

#### 5. Fixed typos & currency consistency
**Files:** `AddView.swift`, `ContentView.swift`, `ItemInfo.swift`, `OverView.swift`  
**Fixes:**
- `"Discription"` → `"Description"` (AddView placeholder)
- `"Amount Spend"` → `"Amount Spent"` (OverView label)
- `"$"` → `"₹"` in ItemInfo amount display (consistent with INR usage)
- `"INR"` → `"₹"` with formatted output in entries list (`String(format: "%.2f", amount)`)

#### 6. Deleted unused `SwiftUIView.swift`
**File Deleted:** `SwiftUIView.swift`  
**What:** Contained a basic NavigationSplitView scaffold with no connection to the rest of the app. Dead code that could confuse future contributors.

#### 7. Added form validation in `AddView`
**File:** `AddView.swift`  
**What:** Previously, tapping Save with an empty or zero amount would create an item with `0.0` amount. No validation or user feedback.  
**Fix:** Added `guard` check that validates the amount is a valid number > 0. Shows an alert with a clear message if validation fails. Also dismisses the sheet (`isPresented = false`) after successful save.

#### 8. Fixed deprecated `onChange` syntax
**Files:** `MonthChartView.swift`, `WeekChartView.swift`, `YearChartView.swift`, `OverView.swift`  
**What:** Used the iOS 16 `.onChange(of:) { newValue in }` one-parameter closure, deprecated since iOS 17.  
**Fix:** Updated to iOS 17+ two-parameter syntax: `.onChange(of:) { oldValue, newValue in }`.

#### 9. Fixed `deleteAllItems` save-per-loop performance issue
**File:** `ContentView.swift`  
**What:** `deleteAllItems()` called `modelContext.save()` after deleting each individual item — resulting in N save operations (one per item + one per daily summary + one per monthly summary).  
**Fix:** Now delegates to `ExpenseDataManager.deleteAllData()` which deletes everything first, then calls `save()` once.

---

## Phase 2 — Feature Implementation (March 1, 2026)

### Changes Made

#### 1. Renamed `Categorys` → `ExpenseCategory`
**Files:** All Swift files referencing the enum  
**What:** The enum was named `Categorys` (grammatically incorrect). Renamed to `ExpenseCategory` following Swift naming conventions. Since SwiftData stores the `rawValue` (String), no data migration is needed.

#### 2. Added `displayName` computed property to `ExpenseCategory`
**File:** `Item.swift`  
**What:** Added a `displayName` property that converts camelCase raw values into readable titles (e.g., `personalCare` → `"Personal Care"`, `publicTransport` → `"Public Transport"`). All views now use `.displayName` instead of `.rawValue.capitalized` which produced incorrect output like `"Personalcare"`.

#### 3. Added Budget model (SwiftData)
**File:** `Item.swift`, `ExpenseApp.swift`  
**What:** New `@Model class Budget` with properties: `id`, `category` (ExpenseCategory), `monthlyLimit` (Double), `createdDate`. Registered in the `ModelContainer` schema alongside Item, DailyCategorySummary, and MonthlyCategorySummary.

#### 4. Created BudgetView with full management UI
**File Created:** `BudgetView.swift`  
**What:** Complete budget management system including:
- **Monthly summary**: Total budget, total spent, remaining
- **Category budgets list**: Each shows a progress bar (blue → orange at 80% → red when over)
- **Over budget alerts section**: Automatically highlights categories exceeding their limit
- **Add Budget sheet**: Category picker (excludes already-budgeted categories), amount input, validation
- **Delete budgets** via swipe-to-delete with EditButton

#### 5. Implemented ComparisonView
**File Created:** `ComparisonView.swift`  
**What:** Full period-over-period comparison tool:
- **Two date range pickers**: Period A (current) and Period B (previous), defaulting to this month vs last month
- **Summary cards**: Total for each period + percentage change (green = down, red = up)
- **Grouped bar chart**: Side-by-side bars per category using Swift Charts
- **Category breakdown table**: Shows exact amounts for each period with % change per category

#### 6. Implemented TrendsView
**File Created:** `TrendsView.swift`  
**What:** Spending trends analysis dashboard:
- **Period picker**: 7 / 30 / 90 days (segmented control)
- **Stat cards**: Total spend, daily average, peak day
- **Trend indicator**: Compares first vs second half of period to detect increasing/decreasing/stable spending
- **Daily spending chart**: Bar marks with a 7-day moving average line overlay (with legend)
- **Top categories**: Horizontal bar chart showing top 10 categories by amount
- **Day details**: Highest/lowest spending days, total entries, active days

#### 7. Added search/filter to EntryView
**File:** `ContentView.swift`  
**What:** Added `.searchable()` modifier to the entries list. Users can search by:
- Description text
- Category name
- Amount  
Search is real-time and updates the list as you type. Delete operations correctly reference filtered items.

#### 8. Added Budget section to sidebar
**File:** `ContentView.swift`  
**What:** Added `.budget` case to the `Section` enum. New "Budget" option appears in the main sidebar navigation between "Data" and "About Us".

#### 9. Built proper AboutUsView
**File:** `ContentView.swift`  
**What:** Replaced the placeholder `Text("About Us")` with a full info page showing:
- App icon and version
- Developer info, tech stack, platform, start date
- Feature list with SF Symbol icons
- Clean card-based layout with `AboutRow` and `FeatureRow` helper views

#### 10. Removed stub views from DataView
**File:** `DataView.swift`  
**What:** Removed the placeholder `ComparisonView` and `TrendsView` structs (which just showed `Text("Comparison")` / `Text("Trends")`). These are now fully implemented in their own files.

---

## Remaining Work (Future Phases)

### Architecture
- [ ] Introduce MVVM with `@Observable` view models
- [ ] Evaluate if DailyCategorySummary / MonthlyCategorySummary can be replaced with computed aggregations
- [ ] Adopt Swift 6 strict concurrency (`Sendable`, `async/await`)

### Features
- [ ] Build iPhone-adaptive layout
- [ ] Add WidgetKit widgets for daily spend summary
- [ ] Implement App Intents for Siri logging ("Hey Siri, log ₹150 for coffee")
- [ ] Add data export (CSV/PDF)
- [ ] Implement CloudKit sync across devices
- [ ] Add recurring/scheduled expenses

### iOS 26 Polish
- [x] Adopt Liquid Glass design system (translucent toolbars, tab bars)
- [x] Add Control Center widget for quick-log expense
- [x] Integrate TipKit for onboarding and feature discovery
- [x] Add `.sensoryFeedback()` for satisfying entry confirmations
- [ ] Explore FinanceKit integration for auto-importing transactions
- [x] Leverage enhanced Swift Charts APIs (annotations, animations)
- [ ] Use SwiftData `#Expression` macros for aggregate queries

---

## Phase 3 — iOS 26 Polish (March 1, 2026)

### Changes Made

#### 1. Integrated TipKit for onboarding & feature discovery
**File Created:** `ExpenseTips.swift`  
**Files Modified:** `ExpenseApp.swift`, `ContentView.swift`, `AddView.swift`, `BudgetView.swift`, `TrendsView.swift`, `ComparisonView.swift`, `OverView.swift`  
**What:** Created 6 contextual tips using TipKit framework (iOS 17+):
- **AddExpenseTip** — Shown on the + button when user hasn't added an expense yet
- **SearchExpensesTip** — Shown in EntryView as a TipView above the entries list
- **SetBudgetTip** — Shown in BudgetView for first-time visitors
- **ViewTrendsTip** — Shown in TrendsView for feature discovery
- **CompareSpendingTip** — Shown in ComparisonView explaining period comparison
- **OverviewTip** — Shown in OverviewView explaining pie chart interaction  
Tips use `@Parameter` and `#Rule` for conditional display. `Tips.configure()` called in `ExpenseApp.init()`.

#### 2. Added `.sensoryFeedback()` haptic feedback
**Files Modified:** `AddView.swift`, `ContentView.swift`, `BudgetView.swift`  
**What:** Added iOS 17+ `.sensoryFeedback()` modifier for tactile confirmation:
- **`.success`** trigger on AddView save (expense created) and AddBudgetView save (budget created)
- **`.impact(flexibility: .solid, intensity: 0.5)`** on delete actions in EntryView and BudgetView  
Uses `@State private var saveTrigger`/`deleteTrigger` booleans toggled on action to fire the feedback.

#### 3. Applied glass materials (Liquid Glass design direction)
**Files Modified:** `ContentView.swift`, `ComparisonView.swift`, `TrendsView.swift`  
**What:** Replaced opaque `Color.secondary.opacity(...)` backgrounds with `.ultraThinMaterial` for a modern translucent glass look:
- **SidebarLabel** — uses `.ultraThinMaterial` background with blue overlay when selected
- **AddButton** — floating action button now uses `.ultraThinMaterial` with subtle shadow
- **AboutUsView cards** — info card and features card use `.ultraThinMaterial`
- **StatCard** (TrendsView) — already using `.ultraThinMaterial`
- **SummaryCard** (ComparisonView) — now uses `.ultraThinMaterial` with subtle color overlay
- **Chart annotations** — selected-value popups use `.ultraThinMaterial` pill background

#### 4. Enhanced Swift Charts with annotations
**Files Modified:** `WeekChartView.swift`, `MonthChartView.swift`, `YearChartView.swift`  
**What:** Added interactive chart annotations:
- **Bar value annotations** — Each bar shows its amount value above it (`.annotation(position: .top)`)
- **RuleMark selection annotations** — When user taps a bar, the selection RuleMark shows a glass-material popover with the formatted amount (₹ symbol, bold font)
- **MonthChartView** — Added missing bar annotations for consistency with Week/Year views

#### 5. Created widget extension scaffolding
**File Created:** `ExpenseWidgets.swift`  
**What:** Complete WidgetKit implementation ready for a Widget Extension target:
- **ExpenseTimelineProvider** — Timeline provider with placeholder, snapshot, and timeline
- **ExpenseWidgetEntry** — Entry with today's total, weekly total, top category
- **ExpenseWidgetSmallView** — Small widget showing today's spending with glass material background
- **ExpenseWidgetMediumView** — Medium widget with today + weekly spend + top category
- **ExpenseHomeWidget** — Static widget configuration supporting small and medium sizes
- **Control Center widget** — Commented-out `ControlWidget` skeleton for iOS 18+
- Includes setup instructions for creating the Widget Extension target in Xcode

#### 6. Updated app version
**File:** `ContentView.swift` (AboutUsView)  
**What:** Bumped version from 1.1.0 to 1.2.0 — "iOS 26 Ready". Added TipKit and haptic feedback to the features list and tech stack.

#### 7. Updated `project.pbxproj`
**File:** `project.pbxproj`  
**What:** Added `ExpenseTips.swift` and `ExpenseWidgets.swift` to all 4 required pbxproj sections (PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase).

## Status Summary

- **Completed:**
  - Phase 1 bug fixes (state, logging, shared data manager, validation, save performance).
  - Phase 2 feature set (Budget, Trends, Comparison, search, sidebar Budget section).
  - Phase 3 polish:
    - TipKit integration and contextual tips.
    - Liquid Glass styling (.ultraThinMaterial) across key UI components.
    - Sensory feedback (`.sensoryFeedback`) for add/delete/save actions.
    - Chart annotations and selection popovers for Week/Month/Year charts.
    - Widget scaffolding (`ExpenseWidgets.swift`) and pbxproj entries for new files.

- **Remaining / Next Work:**
  - Create the Widget Extension target in Xcode and wire shared data (App Group or shared framework). (Scaffolding possible without enrollment; App Groups/provisioning require Apple Developer Program)
  - Explore and integrate FinanceKit (transaction import) — requires entitlement checks and testing on-device.
  - Add SwiftData `#Expression` aggregates where beneficial (needs Xcode/iOS toolchain support).
  - Add MVVM view models, tests, and migration plan for larger datasets.
  - iPhone-adaptive layouts and accessibility/localization polish.
  - Final QA, performance profiling, and App Store release prep. (Requires Apple Developer Program to distribute)

- **Blocked / Requires Apple Developer Program (skip until enrolled):**
  - Implement a Control Center widget using the ControlWidget API (iOS 18+) in the widget target. (Requires provisioning / device testing)
  - Cloud sync (CloudKit) and App Intents (Siri shortcuts) for cross-device and voice entry. (Requires iCloud/App ID & Siri entitlements)
  - App Store release / distribution (Requires Apple Developer Program)

---

## File Inventory (Post Phase 3)

| File | Purpose | Status |
|---|---|---|
| `ExpenseApp.swift` | App entry point, ModelContainer setup, **TipKit configuration** | ✅ Updated |
| `Item.swift` | Data models (Item, DailyCategorySummary, MonthlyCategorySummary, Budget, ExpenseCategory enum, sample data) | ✅ Unchanged |
| `ExpenseDataManager.swift` | Shared logic for adding/deleting items and updating summaries | ✅ Unchanged |
| `ContentView.swift` | Main NavigationSplitView, EntryView (search + **TipKit** + **haptics**), SidebarLabel (**glass material**), AddButton (**glass + tip**), AboutUsView (**v1.2.0 + glass cards**) | ✅ Updated |
| `AddView.swift` | Expense entry form (**sensoryFeedback on save**, TipKit parameter update) | ✅ Updated |
| `ItemInfo.swift` | Expense detail view | ✅ Unchanged |
| `OverView.swift` | Overview with pie chart (**OverviewTip**) | ✅ Updated |
| `ChartView.swift` | Chart wrapper (week/month/year switcher) | ✅ Unchanged |
| `MonthChartView.swift` | Monthly bar chart (**bar annotations added**) | ✅ Updated |
| `WeekChartView.swift` | Weekly bar chart (annotations + glass popover) | ✅ Unchanged |
| `YearChartView.swift` | Yearly bar chart (annotations + glass popover) | ✅ Unchanged |
| `DataView.swift` | Data sub-navigation (Overview, Comparison, Trends) | ✅ Unchanged |
| `BudgetView.swift` | Budget management (**TipKit + sensoryFeedback on save/delete**) | ✅ Updated |
| `ComparisonView.swift` | Period comparison (**TipKit + glass SummaryCard**) | ✅ Updated |
| `TrendsView.swift` | Spending trends (**TipKit + glass StatCard**) | ✅ Updated |
| `ExpenseTips.swift` | **NEW** — TipKit tips (6 tips for onboarding & feature discovery) | ✅ Added |
| `ExpenseWidgets.swift` | **NEW** — WidgetKit widget scaffolding (Home Screen + Control Center) | ✅ Added |

---

## Phase 3 — iPhone UX Redesign & Feature Expansion (March 2, 2026)

### Design Goals
- iPhone-first experience with intuitive navigation
- Decision-focused analytics (not just data display)
- Beautiful, clean visual hierarchy with consistent card styling
- Progressive disclosure: summary first, deep analytics on demand
- Budget coaching and financial health scoring

### Changes Made

#### 1. Adaptive Navigation: TabView for iPhone, SplitView for iPad
**File:** `ContentView.swift`
**What:** Replaced the single `NavigationSplitView` (desktop-first) with an adaptive layout. On compact size class (iPhone), uses a `TabView` with 5 tabs: Home, Entries, Analytics, Budget, About. On regular size class (iPad/Mac), keeps the `NavigationSplitView` sidebar.
**Why:** The sidebar-based navigation was unusable on iPhone — it collapsed awkwardly and required multiple taps for basic actions.

#### 2. New Home Dashboard
**File Created:** `HomeView.swift`
**What:** Beautiful iPhone-first home screen with:
- Hero summary card: Today's spend, This Month total with % change vs last month, Budget remaining with risk level
- Ring chart: Top 8 categories for current month with tap-to-highlight
- 7-Day bar chart: Simple weekly spending visualization
- Insight strip: Top category, peak spend day, daily budget remaining, month-over-month change
- Quick action buttons: Add Expense, All Entries, Budgets

#### 3. Entry List Redesign (Push-Detail)
**File:** `ContentView.swift`
**What:** Replaced the side-by-side list/detail layout with an `EntryListView` that groups entries by day with section headers. Each entry uses a clean `EntryRow` with category icon, name, description, amount, and time. Tapping pushes to the `ItemInfo` detail screen via `NavigationLink`.
**Why:** The old side-by-side layout was forced on iPhone, making entries tiny and detail views cramped.

#### 4. Clean Add Expense Form
**File:** `AddView.swift`
**What:** Complete rebuild from a two-column GeometryReader-based layout to a standard single-column `Form` with proper sections: Amount (with ₹ prefix), Category (searchable + `.navigationLink` picker), Date & Time (separate pickers), Description (expandable text field). Added proper Cancel/Save navigation bar buttons.
**Why:** The old layout was desktop-oriented: two columns that didn't fit iPhone screens, a tiny floating save button with arbitrary offsets, and a WheelPicker that was unusable on phone.

#### 5. Clean Expense Detail
**File:** `ItemInfo.swift`
**What:** Removed the garish yellow background and thick border. Replaced with: amount hero section (large rounded number), structured detail rows (date, time, category, description) in a material card, and category spending history chart.
**Why:** The old design used `.background(Color.yellow.opacity(0.3))` and `.border(Color.secondary, width: 5)` which looked noisy and unprofessional.

#### 6. OverviewView with Decision-Focused Insights
**File:** `OverView.swift`
**What:** Complete redesign as a ScrollView with:
- Period picker (7/14/30 days + custom)
- Summary cards: Period total, % change vs previous period, budget used %, top overspend category
- Ring chart with interactive selection and selected-category callout
- Insight cards: Top category %, period change, budget warning
- Historical chart (time-series) embedded at bottom
**Why:** The old view was just a pie chart + raw chart stacked with Rectangle separators — no context, no decisions, no actionable takeaways.

#### 7. Simplified ChartView
**File:** `ChartView.swift`
**What:** Removed the side-by-side `HStack` with `GeometryReader` that put summary text in 30% width and chart in 70%. Now uses a simple vertical stack: segmented picker → clean summary label → chart. Summary text is concise and secondary.
**Why:** The old HStack layout forced text and chart side-by-side, which was cramped on iPhone and produced long, hard-to-read sentences.

#### 8. DataView with Proper Navigation
**File:** `DataView.swift`
**What:** Replaced the nested `NavigationView` (which caused double nav bars on iPhone) with a `List` using `NavigationLink(value:)` and `.navigationDestination`. Added Financial Health as a 4th analytics section. Each section now has an icon, title, and description.
**Why:** The nested NavigationView was the #1 cause of double-navigation-bar bugs on iPhone.

#### 9. Budget Coaching Nudges
**File:** `BudgetView.swift`
**What:** Added a "Coaching" section that generates smart nudges based on budget vs actual spending:
- Over budget: "Avoid further spending in this category"
- Spending too fast: "Limit to ₹X/day to stay on track" (based on days remaining)
- Under budget: Positive reinforcement "Great job!"
- All on track: "Keep it up!"

#### 10. Financial Health Score
**File Created:** `FinancialHealthView.swift`
**What:** A 0–100 financial health score computed from three components:
- Budget Adherence (0–40 pts): How well you stay within budgets
- Spend Stability (0–30 pts): Coefficient of variation of daily spending (lower = better)
- Month vs Last Month (0–30 pts): Spending less than last month = higher score
Includes: animated score ring, breakdown bars, and personalized recommendations.

#### 11. Visual Consistency
**All files**
**What:**
- Consistent `.ultraThinMaterial` card backgrounds with `RoundedRectangle(cornerRadius: 16)` for major cards, `12` for sub-cards
- Consistent typography: `.headline` for section titles, `.subheadline` for content, `.caption` for metadata
- Reusable components: `InsightRow`, `QuickActionButton`, `QuickActionLabel`, `DetailRow`, `SummaryCard`, `StatCard`, `ScoreBreakdownRow`
- Consistent spacing: 20pt between major sections, 12pt within sections
- Category icons in `EntryRow` via `iconForCategory()` mapping

### Updated File Summary

| File | Purpose | Status |
|---|---|---|
| `ContentView.swift` | Adaptive TabView/SplitView + EntryListView + EntryRow + AboutUsView | ✅ Rewritten |
| `HomeView.swift` | **NEW** — iPhone-first home dashboard | ✅ Added |
| `FinancialHealthView.swift` | **NEW** — Financial health score (0–100) | ✅ Added |
| `AddView.swift` | Clean single-column Form | ✅ Rewritten |
| `ItemInfo.swift` | Clean expense detail view | ✅ Rewritten |
| `OverView.swift` | Decision-focused overview with insight cards | ✅ Rewritten |
| `ChartView.swift` | Simplified vertical layout | ✅ Rewritten |
| `DataView.swift` | Proper navigation with 4 analytics sections | ✅ Rewritten |
| `BudgetView.swift` | Added coaching nudges section | ✅ Updated |
