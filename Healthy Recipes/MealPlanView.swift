//
//  MealPlanView.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 21/10/2026.
//

import Foundation
import SwiftUI
import SwiftData

// A meal is linked by its stable recipe ID. No network requests or duplicate recipe data.
@Model
final class MealPlanEntry {
    var id: UUID
    var day: Date
    var slotKey: String
    var recipeID: String

    init(day: Date, slot: MealSlot, recipeID: String) {
        self.id = UUID()
        self.day = Calendar.current.startOfDay(for: day)
        self.slotKey = slot.rawValue
        self.recipeID = recipeID
    }
}

enum MealSlot: String, CaseIterable, Identifiable, Hashable {
    case breakfast, lunch, snack, dinner
    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .snack: "Snack"
        case .dinner: "Dinner"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: "cup.and.saucer"
        case .lunch: "sun.max"
        case .snack: "carrot"
        case .dinner: "fork.knife"
        }
    }
}

struct MealPlanSuggestion: Equatable {
    let day: Date
    let slot: MealSlot?
    var dayLabel: String { MealPlanDates.label(day) }
}

private enum MealPlanDates {
    static func weekStart(for date: Date) -> Date {
        var isoCalendar = Calendar(identifier: .iso8601)  // Monday is always first.
        isoCalendar.timeZone = .current
        return isoCalendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? Calendar.current.startOfDay(for: date)
    }

    static func days(starting firstDay: Date) -> [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: firstDay) }
    }

    static func label(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE d MMM"
        return formatter.string(from: date)
    }

    static func shortLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    static func normalized(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }

    /// Shared by the Meal Plan tab and the Add to Meal Plan sheet.
    static func day(at offset: Int) -> Date {
        let today = normalized(.now)
        return Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
    }

    static func relativeDayLabel(for offset: Int) -> String {
        switch offset {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        case 2...: "In \(offset) days"
        default: "\(-offset) days ago"
        }
    }
}

@MainActor
private enum MealPlanStorage {
    static func entry(for day: Date, slot: MealSlot, in entries: [MealPlanEntry]) -> MealPlanEntry? {
        entries.first {
            Calendar.current.isDate($0.day, inSameDayAs: day) && $0.slotKey == slot.rawValue
        }
    }

    static func assign(_ recipeID: String, day: Date, slot: MealSlot,
                       entries: [MealPlanEntry], modelContext: ModelContext) throws {
        if let existing = entry(for: day, slot: slot, in: entries) {
            existing.recipeID = recipeID
        } else {
            modelContext.insert(MealPlanEntry(day: day, slot: slot, recipeID: recipeID))
        }
        try modelContext.save()
    }

    static func remove(day: Date, slot: MealSlot,
                       entries: [MealPlanEntry], modelContext: ModelContext) throws {
        if let existing = entry(for: day, slot: slot, in: entries) {
            modelContext.delete(existing)
            try modelContext.save()
        }
    }
}

/// Shared day card ensures both screens keep precisely the same proportions and style.
private struct MealPlanDayCard: View {
    let day: Date
    let entries: [MealPlanEntry]
    let recipes: [StoredRecipe]
    let isExpanded: Bool
    let isChoosing: Bool
    let highlightedSlot: MealSlot?
    let onToggle: () -> Void
    let onAddDay: () -> Void
    let onSlotSelected: (MealSlot) -> Void
    let onRemove: (MealSlot) -> Void

    private let columns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]

    private func recipe(for slot: MealSlot) -> StoredRecipe? {
        guard let entry = MealPlanStorage.entry(for: day, slot: slot, in: entries) else { return nil }
        return recipes.first { $0.id == entry.recipeID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    HStack {
                        Text(MealPlanDates.label(day))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer(minLength: 6)
                    }
                    .contentShape(Rectangle())
                    .frame(height: 62)
                }
                .buttonStyle(.plain)

                Button(action: isExpanded ? onToggle : onAddDay) {
                    Image(systemName: isExpanded ? "minus" : "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppTheme.softGreen)
                        .frame(width: 41, height: 41)
                        .background(AppTheme.searchBackground, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse \(MealPlanDates.label(day))" :
                                    (isChoosing ? "Show meals" : "Choose a recipe for \(MealPlanDates.label(day))"))
            }
            .padding(.horizontal, 19)

            if isExpanded {
                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(MealSlot.allCases) { slot in
                        let assignedRecipe = recipe(for: slot)
                        if !isChoosing, let assignedRecipe {
                            ZStack(alignment: .topTrailing) {
                                NavigationLink(value: assignedRecipe.asRecipe) {
                                    slotTile(slot, title: assignedRecipe.title, isFilled: true)
                                }
                                .buttonStyle(.plain)
                                Button { onRemove(slot) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(AppTheme.secondaryText.opacity(0.68))
                                        .frame(width: 29, height: 29)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(assignedRecipe.title) from \(slot.title)")
                            }
                        } else {
                            Button { onSlotSelected(slot) } label: {
                                slotTile(slot, title: assignedRecipe?.title, isFilled: assignedRecipe != nil)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 16)
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: isExpanded ? 28 : 35, style: .continuous))
        .shadow(color: .black.opacity(0.11), radius: 17, x: 0, y: 5)
    }

    private func slotTile(_ slot: MealSlot, title: String?, isFilled: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: slot.symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(isFilled ? AppTheme.primaryGreen : AppTheme.softGreen)
                .frame(height: 27)
            Text(slot.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            if let title {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.primaryGreen)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32, alignment: .top)
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.softGreen)
                    .frame(height: 32, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 91)
        .padding(.horizontal, 6)
        .background(
            (highlightedSlot == slot ? AppTheme.chipBackground : AppTheme.background.opacity(0.7)),
            in: RoundedRectangle(cornerRadius: 17)
        )
        .overlay {
            if highlightedSlot == slot {
                RoundedRectangle(cornerRadius: 17)
                    .strokeBorder(AppTheme.primaryGreen.opacity(0.6), lineWidth: 1.3)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 17))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(slot.title), \(title ?? "add a recipe")")
    }
}

/// Rolling seven-day plan; tapping + navigates to Recipes. Tapping a day expands it.
struct MealPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [MealPlanEntry]
    @Query private var recipes: [StoredRecipe]

    let chooseRecipe: (Date, MealSlot?) -> Void
    @State private var dayOffset = 0
    @State private var expandedDays: Set<Date> = []
    @State private var pendingRemoval: (day: Date, slot: MealSlot)?
    @State private var showingError = false
    @State private var initializedDays = false

    // Display today and the following six days. Each arrow moves the window by one day.
    private var firstDay: Date { MealPlanDates.day(at: dayOffset) }
    private var days: [Date] { MealPlanDates.days(starting: firstDay) }
    private var relativeDayLabel: String { MealPlanDates.relativeDayLabel(for: dayOffset) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Meal Plan")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.top, 18)

                HStack(spacing: 12) {
                    Text("\(MealPlanDates.shortLabel(days.first ?? firstDay)) – \(MealPlanDates.shortLabel(days.last ?? firstDay))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer()
                    Button { moveDay(-1) } label: {
                        Image(systemName: "chevron.left").frame(width: 32, height: 33)
                    }
                    Button(relativeDayLabel) {
                        withAnimation(.easeInOut(duration: 0.22)) { dayOffset = 0 }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .accessibilityLabel("Return to today")
                    Button { moveDay(1) } label: {
                        Image(systemName: "chevron.right").frame(width: 32, height: 33)
                    }
                }
                .foregroundStyle(AppTheme.primaryGreen)
                .padding(.horizontal, 5)

                LazyVStack(spacing: 16) {
                    ForEach(days, id: \.self) { day in
                        MealPlanDayCard(
                            day: day, entries: entries, recipes: recipes,
                            isExpanded: expandedDays.contains(day),
                            isChoosing: false, highlightedSlot: nil,
                            onToggle: { toggle(day) },
                            onAddDay: { chooseRecipe(day, nil) },
                            onSlotSelected: { chooseRecipe(day, $0) },
                            onRemove: { pendingRemoval = (day, $0) }
                        )
                    }
                }
            }
            .padding(.horizontal, 19)
            .padding(.bottom, 115)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if !initializedDays {
                let visible = Set(days.map(MealPlanDates.normalized))
                expandedDays = Set(entries.map { MealPlanDates.normalized($0.day) })
                    .intersection(visible)
                initializedDays = true
            }
        }
        .confirmationDialog("Remove recipe?", isPresented: Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        )) {
            Button("Remove from Meal Plan", role: .destructive) {
                guard let removal = pendingRemoval else { return }
                do {
                    try MealPlanStorage.remove(day: removal.day, slot: removal.slot,
                                               entries: entries, modelContext: modelContext)
                } catch { showingError = true }
                pendingRemoval = nil
            }
        } message: { Text("Only this planned meal will be removed.") }
        .alert("Couldn't update Meal Plan", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        }
    }

    private func moveDay(_ by: Int) {
        withAnimation(.easeInOut(duration: 0.22)) { dayOffset += by }
    }
    private func toggle(_ day: Date) {
        withAnimation(.easeInOut(duration: 0.22)) {
            if expandedDays.contains(day) { expandedDays.remove(day) }
            else { expandedDays.insert(day) }
        }
    }
}

/// Same day cards in selection mode. Pick a slot; an existing meal requires confirmation.
struct AddToMealPlanSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [MealPlanEntry]
    @Query private var recipes: [StoredRecipe]

    let recipe: Recipe
    let suggestion: MealPlanSuggestion?
    let onAdded: () -> Void

    @State private var dayOffset: Int
    @State private var expandedDays: Set<Date> = []
    @State private var pendingReplacement: (day: Date, slot: MealSlot)?
    @State private var showingError = false

    init(recipe: Recipe, suggestion: MealPlanSuggestion?, onAdded: @escaping () -> Void) {
        self.recipe = recipe
        self.suggestion = suggestion
        self.onAdded = onAdded
        // Opening from Meal Plan starts on the suggested day, not on Monday.
        let today = MealPlanDates.normalized(.now)
        let suggestedDay = MealPlanDates.normalized(suggestion?.day ?? today)
        let initialOffset = Calendar.current.dateComponents([.day], from: today, to: suggestedDay).day ?? 0
        _dayOffset = State(initialValue: initialOffset)
    }

    private var firstDay: Date { MealPlanDates.day(at: dayOffset) }
    private var days: [Date] { MealPlanDates.days(starting: firstDay) }
    private var relativeDayLabel: String { MealPlanDates.relativeDayLabel(for: dayOffset) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(width: 48, height: 48)
                            .background(Color.black.opacity(0.06), in: Circle())
                    }
                    .accessibilityLabel("Back")
                    Spacer()
                    Text("Add to Meal Plan")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Color.clear.frame(width: 48, height: 48)
                }
                .padding(.bottom, 3)

                HStack(spacing: 12) {
                    Text("\(MealPlanDates.shortLabel(days.first ?? firstDay)) – \(MealPlanDates.shortLabel(days.last ?? firstDay))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer()
                    Button { moveDay(-1) } label: {
                        Image(systemName: "chevron.left").frame(width: 32, height: 33)
                    }
                    Button(relativeDayLabel) {
                        withAnimation(.easeInOut(duration: 0.22)) { dayOffset = 0 }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .accessibilityLabel("Return to today")
                    Button { moveDay(1) } label: {
                        Image(systemName: "chevron.right").frame(width: 32, height: 33)
                    }
                }
                .foregroundStyle(AppTheme.primaryGreen)
                .padding(.horizontal, 5)

                LazyVStack(spacing: 16) {
                    ForEach(days, id: \.self) { day in
                        MealPlanDayCard(
                            day: day, entries: entries, recipes: recipes,
                            isExpanded: expandedDays.contains(day),
                            isChoosing: true,
                            highlightedSlot: isSuggested(day) ? suggestion?.slot : nil,
                            onToggle: { toggle(day) },
                            onAddDay: { toggle(day) },
                            onSlotSelected: { select(day: day, slot: $0) },
                            onRemove: { _ in }
                        )
                    }
                }
            }
            .padding(.horizontal, 19)
            .padding(.top, 12)
            .padding(.bottom, 45)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { expandSuggested() }
        .confirmationDialog("Replace planned meal?", isPresented: Binding(
            get: { pendingReplacement != nil },
            set: { if !$0 { pendingReplacement = nil } }
        )) {
            Button("Replace meal") {
                guard let proposed = pendingReplacement else { return }
                save(day: proposed.day, slot: proposed.slot)
                pendingReplacement = nil
            }
        } message: { Text("This will replace the recipe already assigned to this meal.") }
        .alert("Couldn't save Meal Plan", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: { Text("Please try again.") }
    }

    private func moveDay(_ by: Int) {
        withAnimation(.easeInOut(duration: 0.22)) { dayOffset += by }
    }

    private func isSuggested(_ day: Date) -> Bool {
        guard let suggestion else { return false }
        return Calendar.current.isDate(suggestion.day, inSameDayAs: day)
    }

    private func expandSuggested() {
        expandedDays = suggestion.map { [MealPlanDates.normalized($0.day)] } ?? []
    }

    private func toggle(_ day: Date) {
        withAnimation(.easeInOut(duration: 0.22)) {
            if expandedDays.contains(day) { expandedDays.remove(day) }
            else { expandedDays.insert(day) }
        }
    }

    private func select(day: Date, slot: MealSlot) {
        if let existing = MealPlanStorage.entry(for: day, slot: slot, in: entries),
           existing.recipeID != recipe.id {
            pendingReplacement = (day, slot)
        } else {
            save(day: day, slot: slot)
        }
    }

    private func save(day: Date, slot: MealSlot) {
        do {
            try MealPlanStorage.assign(recipe.id, day: day, slot: slot,
                                       entries: entries, modelContext: modelContext)
            onAdded()
            dismiss()
        } catch { showingError = true }
    }
}
