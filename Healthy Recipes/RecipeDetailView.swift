//
//  RecipeDetailView.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var storedRecipes: [StoredRecipe]
    @Query private var cartItems: [GroceryItem]

    let recipe: Recipe
    var suggestedMeal: MealPlanSuggestion? = nil
    var onAddedToMealPlan: (() -> Void)? = nil
    @State private var showingMealPlanSheet = false
    @State private var servings = 1
    @State private var showingEditor = false
    @State private var confirmingDelete = false
    @State private var deleteFailed = false
    @State private var showingAdded = false

    private var stored: StoredRecipe? { storedRecipes.first { $0.id == recipe.id } }
    private var current: Recipe { stored?.asRecipe ?? recipe }
    private var preparationSteps: [String] {
        current.steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 15)

                RecipeArtwork(recipe: current)
                    .frame(height: 195)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.bottom, 17)

                titleAndSummary
                    .padding(.horizontal, 12)
                    .padding(.bottom, 20)

                if current.proteinGrams != nil || current.carbsGrams != nil ||
                   current.fatGrams != nil {
                    RecipeNutritionPanel(
                        proteinGrams: current.proteinGrams,
                        carbsGrams: current.carbsGrams,
                        fatGrams: current.fatGrams
                    )
                    .padding(.bottom, 25)
                }

                addToMealPlanButton
                    .padding(.bottom, 25)

                ingredientsSection

                if !preparationSteps.isEmpty {
                    instructionsSection
                        .padding(.top, 21)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(AppTheme.background.ignoresSafeArea())
        // A custom header matches the Sketch mockup without changing navigation behavior.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { servings = 1 }
        .sheet(isPresented: $showingMealPlanSheet) {
            AddToMealPlanSheet(recipe: current, suggestion: suggestedMeal) {
                onAddedToMealPlan?()
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let stored { NavigationStack { RecipeEditorView(existing: stored) } }
        }
        .confirmationDialog("Delete this recipe?", isPresented: $confirmingDelete) {
            Button("Delete recipe", role: .destructive) { deleteRecipe() }
        } message: { Text("This recipe will be deleted from your device.") }
        .alert("Added to Groceries", isPresented: $showingAdded) {
            Button("OK", role: .cancel) { }
        } message: { Text("Your ingredient quantities were saved for \(servings) servings.") }
        .alert("Could not delete recipe", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) { }
        } message: { Text("Please try again.") }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 23, weight: .medium))
                    Text("Back")
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundStyle(AppTheme.primaryGreen)
                .padding(.leading, 10)
                .padding(.trailing, 14)
                .frame(height: 42)
                .background(AppTheme.searchBackground, in: Capsule())
                .overlay(Capsule().strokeBorder(AppTheme.primaryGreen.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            if current.isUserCreated {
                Menu {
                    Button { showingEditor = true } label: {
                        Label("Edit recipe", systemImage: "pencil")
                    }
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Delete recipe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryGreen)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                }
                .accessibilityLabel("Recipe options")
            }

            FavoriteButton(recipe: current, prominent: true)
                .background(Circle().fill(.white).shadow(color: .black.opacity(0.12), radius: 6, y: 3))
        }
    }

    private var titleAndSummary: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(current.title)
                .font(.system(size: 27, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 17) {
                Label("\(current.minutes) min total", systemImage: "clock")
                if let calories = current.calories {
                    Label("\(calories) kcal / serving", systemImage: "flame")
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(AppTheme.primaryGreen)
            .lineLimit(1)
            .minimumScaleFactor(0.79)
        }
    }

    private var addToMealPlanButton: some View {
        Button { showingMealPlanSheet = true } label: {
            HStack(spacing: 10) {
                Text("Add to Meal Plan")
                Image(systemName: "calendar")
                    .accessibilityHidden(true)
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppTheme.primaryGreen, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Choose a day and a meal")
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 7) {
                Text("Ingredients")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer(minLength: 4)

                Image(systemName: "person.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.7))
                    .accessibilityHidden(true)

                Text("Servings")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)

                servingsControl
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 9)

            VStack(spacing: 0) {
                ForEach(Array(current.ingredients.enumerated()), id: \.offset) { index, item in
                    ingredientRow(item)

                    if index < current.ingredients.count - 1 {
                        Divider()
                            .overlay(AppTheme.secondaryText.opacity(0.12))
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.075), radius: 16, y: 5)
            .padding(.bottom, 14)

            Button { addAllIngredients() } label: {
                HStack(spacing: 8) {
                    Text("Add to Groceries")
                    Image(systemName: "cart")
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.primaryGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(AppTheme.primaryGreen, lineWidth: 1.2)
                }
                .contentShape(RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            .disabled(current.ingredients.isEmpty)
        }
    }

    private var servingsControl: some View {
        HStack(spacing: 0) {
            Button { servings = max(1, servings - 1) } label: {
                Image(systemName: "minus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 33, height: 38)
            }
            .disabled(servings <= 1)
            .accessibilityLabel("Decrease servings")

            Text("\(servings)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 26)
                .accessibilityLabel("\(servings) servings")

            Button { servings = min(24, servings + 1) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 33, height: 38)
            }
            .disabled(servings >= 24)
            .accessibilityLabel("Increase servings")
        }
        .foregroundStyle(AppTheme.primaryGreen)
        .background(Color.black.opacity(0.045), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Servings")
    }

    private func ingredientRow(_ item: RecipeIngredient) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(item.name)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(QuantityText.format(item.scaled(for: servings, from: current.baseServings))) \(item.unit)")
                .font(.system(size: 16, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.83)

            Button { addIngredient(item) } label: {
                Image(systemName: itemIsCurrentInCart(item) ? "checkmark.circle.fill" : "cart.badge.plus")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(AppTheme.primaryGreen)
                    .frame(width: 37, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(item.name) to Groceries")
        }
        .padding(.leading, 18)
        .padding(.trailing, 9)
        .padding(.vertical, 5)
        .frame(minHeight: 55)
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 12)

            VStack(spacing: 0) {
                ForEach(Array(preparationSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 15) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 29, height: 29)
                            .background(AppTheme.primaryGreen, in: Circle())
                            .accessibilityHidden(true)

                        Text(step)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 17)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Step \(index + 1): \(step)")

                    if index < preparationSteps.count - 1 {
                        Divider()
                            .overlay(AppTheme.secondaryText.opacity(0.12))
                            .padding(.horizontal, 18)
                    }
                }
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.07), radius: 15, y: 5)
        }
    }

    // The grocery, favorite, editing and deletion behavior is unchanged.
    private func itemIsCurrentInCart(_ item: RecipeIngredient) -> Bool {
        guard let matching = cartItems.first(where: { $0.sourceRecipeID == current.id && $0.ingredientID == item.id }) else {
            return false
        }
        return abs(matching.quantity - item.scaled(for: servings, from: current.baseServings)) < 0.001
    }

    private func upsert(_ item: RecipeIngredient) {
        let qty = item.scaled(for: servings, from: current.baseServings)
        if let saved = cartItems.first(where: { $0.sourceRecipeID == current.id && $0.ingredientID == item.id }) {
            saved.quantity = qty
            saved.name = item.name
            saved.unit = item.unit
            saved.recipeTitle = current.title
        } else {
            modelContext.insert(GroceryItem(recipe: current, ingredient: item, servings: servings))
        }
    }

    private func addIngredient(_ item: RecipeIngredient) {
        upsert(item)
        try? modelContext.save()
    }

    private func addAllIngredients() {
        for item in current.ingredients { upsert(item) }
        try? modelContext.save()
        showingAdded = true
    }

    private func deleteRecipe() {
        guard let stored, stored.isUserCreated else { return }
        for grocery in cartItems where grocery.sourceRecipeID == stored.id {
            modelContext.delete(grocery)
        }
        // Keep the weekly plan consistent if a personal recipe is deleted.
        let plannedEntries = (try? modelContext.fetch(FetchDescriptor<MealPlanEntry>())) ?? []
        for planned in plannedEntries where planned.recipeID == stored.id {
            modelContext.delete(planned)
        }
        let oldImageName = stored.imageName
        modelContext.delete(stored)
        do {
            try modelContext.save()
            RecipeImageStore.deleteIfLocal(named: oldImageName)
            dismiss()
        } catch {
            deleteFailed = true
        }
    }
}

/// Nutrition is intentionally per serving, even when ingredient quantities change.
/// Calories remain under the recipe title rather than appearing in this panel.
private struct RecipeNutritionPanel: View {
    let proteinGrams: Double?
    let carbsGrams: Double?
    let fatGrams: Double?

    private var metrics: [(label: String, grams: Double)] {
        var values: [(label: String, grams: Double)] = []
        if let proteinGrams { values.append(("Protein", proteinGrams)) }
        if let carbsGrams { values.append(("Carbs", carbsGrams)) }
        if let fatGrams { values.append(("Fat", fatGrams)) }
        return values
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Nutrition per serving")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.secondaryText)

            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    VStack(spacing: 5) {
                        Text("\(QuantityText.format(metric.grams)) g")
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(metric.label)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.primaryGreen)
                    }
                    .frame(maxWidth: .infinity)

                    if index < metrics.count - 1 {
                        Rectangle()
                            .fill(AppTheme.secondaryText.opacity(0.35))
                            .frame(width: 1, height: 47)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.chipBackground.opacity(0.55), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(AppTheme.secondaryText.opacity(0.52), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }
}
