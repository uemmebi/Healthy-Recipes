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
    @State private var servings = 2
    @State private var showingEditor = false
    @State private var confirmingDelete = false
    @State private var deleteFailed = false
    @State private var showingAdded = false

    private var stored: StoredRecipe? { storedRecipes.first { $0.id == recipe.id } }
    private var current: Recipe { stored?.asRecipe ?? recipe }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { geo in
                    RecipeArtwork(recipe: current)
                        .frame(width: geo.size.width, height: 230)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .frame(height: 230)
                .padding(.bottom, 19)

                HStack(alignment: .top, spacing: 12) {
                    Text(current.title)
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(AppTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    FavoriteButton(recipe: current, prominent: true)
                }
                .padding(.bottom, 12)

                HStack(spacing: 16) {
                    Label("\(current.minutes) min", systemImage: "clock")
                    if current.calories != nil {
                        Label(current.caloriesText + " / serving", systemImage: "flame")
                    }
                }
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.bottom, 22)

                HStack {
                    Text("Servings")
                        .font(.system(size: 19, weight: .semibold))
                    Spacer()
                    Button { servings = max(2, servings - 1) } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 40, height: 40)
                    }
                    .disabled(servings <= 2)
                    .accessibilityLabel("Decrease servings")
                    Text("\(servings)")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 28)
                        .accessibilityLabel("\(servings) servings")
                    Button { servings = min(24, servings + 1) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 40, height: 40)
                    }
                    .disabled(servings >= 24)
                    .accessibilityLabel("Increase servings")
                }
                .foregroundStyle(AppTheme.primaryGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(AppTheme.chipBackground, in: RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 28)

                HStack {
                    Text("Ingredients")
                        .font(.system(size: 22, weight: .semibold))
                    Spacer()
                    Button { addAllIngredients() } label: {
                        Label("Add all", systemImage: "cart.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .disabled(current.ingredients.isEmpty)
                }
                .foregroundStyle(AppTheme.primaryGreen)
                .padding(.bottom, 12)

                ForEach(current.ingredients) { item in
                    HStack(alignment: .center, spacing: 10) {
                        Text(QuantityText.format(item.scaled(for: servings, from: current.baseServings)))
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.primaryGreen)
                            .frame(minWidth: 32, alignment: .trailing)
                        Text(item.unit)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(minWidth: 35, alignment: .leading)
                        Text(item.name)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button { addIngredient(item) } label: {
                            Image(systemName: itemIsCurrentInCart(item) ? "checkmark.circle.fill" : "cart.badge.plus")
                                .font(.system(size: 20))
                                .foregroundStyle(AppTheme.primaryGreen)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add \(item.name) to Groceries")
                    }
                    .padding(.vertical, 5)
                    Divider().overlay(AppTheme.chipBackground)
                }
                .padding(.bottom, 24)

                Text("Preparation")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.bottom, 16)

                ForEach(Array(current.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 13) {
                        Text("\(index + 1)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.primaryGreen, in: Circle())
                        Text(step)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.bottom, 18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 135)
        }
        .background(AppTheme.background)
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if current.isUserCreated {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showingEditor = true } label: {
                            Label("Edit recipe", systemImage: "pencil")
                        }
                        Button(role: .destructive) { confirmingDelete = true } label: {
                            Label("Delete recipe", systemImage: "trash")
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .onAppear { servings = max(2, current.baseServings) }
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
        modelContext.delete(stored)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            deleteFailed = true
        }
    }
}
