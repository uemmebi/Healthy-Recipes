//
//  GroceryListView.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import Foundation
import SwiftUI
import SwiftData

struct GroceryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryItem.addedAt, order: .forward) private var groceries: [GroceryItem]

    @State private var showingAddItem = false

    private var sections: [GrocerySection] {
        let byIngredient = Dictionary(grouping: groceries) { item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let unit = item.unit.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return "\(name)|\(unit)"
        }

        let combined = byIngredient.values.compactMap { matches -> GroceryDisplayItem? in
            guard let first = matches.first else { return nil }
            return GroceryDisplayItem(
                id: first.id,
                name: first.name.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: matches.reduce(0) { $0 + $1.quantity },
                unit: first.unit.trimmingCharacters(in: .whitespacesAndNewlines),
                checked: matches.allSatisfy(\.checked),
                records: matches,
                category: GroceryCategory.forIngredient(first.name)
            )
        }

        return GroceryCategory.allCases.compactMap { category in
            let rows = combined.filter { $0.category == category }.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return rows.isEmpty ? nil : GrocerySection(category: category, items: rows)
        }
    }

    private var shareText: String {
        let content = sections.map { section in
            let lines = section.items.map { item in
                let checkbox = item.checked ? "☑" : "☐"
                return "\(checkbox) \(item.displayName) — \(item.quantityText)"
            }.joined(separator: "\n")
            return "\(section.category.title)\n\(lines)"
        }.joined(separator: "\n\n")
        return "GROCERIES\n\n\(content)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                Text("Groceries")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                if !groceries.isEmpty {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 25, weight: .regular))
                            .foregroundStyle(AppTheme.primaryGreen)
                            .frame(width: 34, height: 40)
                    }
                    .accessibilityLabel("Share grocery checklist")
                }

                Button {
                    showingAddItem = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(AppTheme.primaryGreen)
                        .frame(width: 34, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add grocery item")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if groceries.isEmpty {
                ContentUnavailableView {
                    Label("Your list is empty", systemImage: "basket")
                } description: {
                    Text("Add an item with +, or add ingredients from a recipe.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 90)
            } else {
                List {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.items) { item in
                                GroceryCard(item: item) {
                                    toggle(item)
                                }
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(section.category.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppTheme.primaryGreen)
                                .textCase(nil)
                                .padding(.leading, 5)
                        }
                        .listSectionSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 0)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 85)
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAddItem) {
            GroceryAddItemSheet { name, quantity, unit in
                addManualItem(name: name, quantity: quantity, unit: unit)
            }
        }
    }

    private func toggle(_ item: GroceryDisplayItem) {
        let newValue = !item.checked
        for record in item.records { record.checked = newValue }
        try? modelContext.save()
    }

    private func delete(_ item: GroceryDisplayItem) {
        for record in item.records { modelContext.delete(record) }
        try? modelContext.save()
    }

    private func addManualItem(name: String, quantity: Double, unit: String) {
        let manualRecipe = Recipe(id: "manual-groceries", title: "Added manually",
                                  minutes: 0, calories: nil, categories: [],
                                  ingredients: [], steps: [], baseServings: 1)
        let ingredient = RecipeIngredient(name: name, quantity: quantity, unit: unit)
        modelContext.insert(GroceryItem(recipe: manualRecipe, ingredient: ingredient, servings: 1))
        try? modelContext.save()
    }
}

private struct GrocerySection: Identifiable {
    let category: GroceryCategory
    let items: [GroceryDisplayItem]
    var id: String { category.rawValue }
}

private struct GroceryDisplayItem: Identifiable {
    let id: String
    let name: String
    let quantity: Double
    let unit: String
    let checked: Bool
    let records: [GroceryItem]
    let category: GroceryCategory

    var displayName: String {
        guard let first = name.first else { return name }
        return first.uppercased() + name.dropFirst()
    }

    var quantityText: String {
        let value = QuantityText.format(quantity)
        if unit.isEmpty { return value }
        let compactUnits: Set<String> = ["g", "kg", "mg", "ml", "l"]
        return compactUnits.contains(unit.lowercased()) ? "\(value)\(unit)" : "\(value) \(unit)"
    }
}

private struct GroceryCard: View {
    let item: GroceryDisplayItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(AppTheme.primaryGreen)
                    .frame(width: 28, height: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.displayName)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(item.checked ? AppTheme.secondaryText : AppTheme.primaryText)
                        .strikethrough(item.checked)
                        .lineLimit(1)

                    Text(item.quantityText)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.secondaryText)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 17)
            .frame(maxWidth: .infinity, minHeight: 65, alignment: .leading)
            .background(Color.white, in: Capsule())
            .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 5)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.displayName), \(item.quantityText)")
        .accessibilityValue(item.checked ? "Completed" : "Not completed")
        .accessibilityHint("Double tap to change its checked state. Swipe left to delete.")
    }
}

private enum GroceryCategory: String, CaseIterable {
    case fresh, pantry, dairy, bakery, meatFish, frozen, other

    var title: String {
        switch self {
        case .fresh: "FRESH"
        case .pantry: "PANTRY"
        case .dairy: "DAIRY"
        case .bakery: "BAKERY"
        case .meatFish: "MEAT & FISH"
        case .frozen: "FROZEN"
        case .other: "OTHER"
        }
    }

    static func forIngredient(_ name: String) -> GroceryCategory {
        let n = name.lowercased()

        func contains(_ keywords: [String]) -> Bool {
            keywords.contains { keyword in
                let escaped = NSRegularExpression.escapedPattern(for: keyword)
                return n.range(of: "\\b\(escaped)\\b", options: .regularExpression) != nil
            }
        }

        if contains(["frozen", "ice cream"]) { return .frozen }
        if contains(["canned", "tinned", "dried", "dry", "jarred", "powder"]) { return .pantry }
        if contains(["milk", "mozzarella", "cheese", "parmesan", "ricotta", "feta",
                     "yogurt", "yoghurt", "cream", "butter", "egg", "eggs", "skyr"]) { return .dairy }
        if contains(["bread", "toast", "bagel", "pita", "tortilla", "wrap", "wraps",
                     "roll", "rolls", "bun", "buns", "croissant"]) { return .bakery }
        if contains(["chicken", "turkey", "beef", "pork", "lamb", "salmon", "tuna",
                     "cod", "shrimp", "prawns", "fish", "steak", "bacon", "sausage"]) { return .meatFish }
        if contains(["pasta", "spaghetti", "penne", "fusilli", "rice", "oats", "oatmeal",
                     "quinoa", "couscous", "flour", "lentils", "chickpeas", "beans",
                     "oil", "vinegar", "soy sauce", "salt", "black pepper", "ground pepper", "pepper flakes", "sugar", "honey",
                     "syrup", "spice", "spices", "paprika", "cumin", "curry", "oregano",
                     "seeds", "nuts", "almonds", "walnuts", "peanut butter", "stock",
                     "broth", "cornstarch", "baking powder", "coconut milk", "chocolate",
                     "mustard", "sauce", "paste", "noodles", "granola"]) { return .pantry }
        if contains(["tomato", "tomatoes", "cucumber", "carrot", "carrots", "avocado",
                     "potato", "potatoes", "spinach", "lettuce", "broccoli", "zucchini",
                     "courgette", "eggplant", "aubergine", "onion", "onions", "garlic",
                     "pepper", "peppers", "mushroom", "mushrooms", "apple", "apples",
                     "banana", "bananas", "orange", "lemon", "lime", "strawberries",
                     "blueberries", "berries", "raspberries", "mango", "pineapple",
                     "grapes", "pear", "pears", "celery", "cabbage", "kale", "arugula",
                     "rocket", "corn", "parsley", "basil", "cilantro", "coriander",
                     "mint", "ginger", "sweet potato", "pumpkin", "leek", "cauliflower",
                     "edamame", "radish", "radishes", "beetroot", "asparagus"]) { return .fresh }
        return .other
    }
}

private struct GroceryAddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String, Double, String) -> Void

    @State private var name = ""
    @State private var quantityText = "1"
    @State private var unit = "pcs"

    private var parsedQuantity: Double? {
        Double(quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "."))
    }

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (parsedQuantity ?? 0).isFinite && (parsedQuantity ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Ingredient name", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("Quantity") {
                    TextField("Amount", text: $quantityText)
                        .keyboardType(.decimalPad)
                    Picker("Unit", selection: $unit) {
                        ForEach(["g", "kg", "ml", "l", "pcs", "tbsp", "tsp", "cups", "cloves", "leaves"], id: \.self) { measure in
                            Text(measure).tag(measure)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.primaryGreen)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Add Grocery Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let quantity = parsedQuantity, canAdd else { return }
                        onAdd(name.trimmingCharacters(in: .whitespacesAndNewlines),
                              quantity, unit.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canAdd)
                }
            }
        }
        .tint(AppTheme.primaryGreen)
        .presentationDetents([.medium, .large])
    }
}
