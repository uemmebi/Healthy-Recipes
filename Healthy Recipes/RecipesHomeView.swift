//
//  RecipesHomeView.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import SwiftUI
import SwiftData

struct RecipesHomeView: View {
    var mealPlanSuggestion: MealPlanSuggestion? = nil
    var cancelMealPlanSuggestion: (() -> Void)? = nil
    @Query(sort: \StoredRecipe.createdAt, order: .forward)
    private var records: [StoredRecipe]
    @State private var searchText = ""
    @State private var selectedCategory: RecipeCategory = .all
    @State private var showingNewRecipe = false

    private var allRecipes: [Recipe] { records.map(\.asRecipe) }
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategory != .all
    }
    private func matches(_ recipe: Recipe) -> Bool {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let textMatch = term.isEmpty || recipe.title.localizedCaseInsensitiveContains(term)
            || recipe.ingredients.contains { $0.name.localizedCaseInsensitiveContains(term) }
        return textMatch && (selectedCategory == .all || recipe.categories.contains(selectedCategory))
    }
    private var searchResults: [Recipe] {
        var seen = Set<String>()
        return allRecipes.filter { matches($0) && seen.insert($0.id).inserted }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
    private var featured: Recipe? {
        let catalog = allRecipes.filter { !$0.isUserCreated }.sorted { $0.id < $1.id }
        guard !catalog.isEmpty else { return nil }
        let day = Int(Calendar.current.startOfDay(for: .now).timeIntervalSince1970 / 86_400)
        return catalog[day % catalog.count]
    }

    private var created: [Recipe] { allRecipes.filter(\.isUserCreated) }
    private var favorites: [Recipe] { allRecipes.filter(\.isFavorite) }
    private var quick: [Recipe] {
        let excluded = Set(created.map(\.id) + [featured?.id].compactMap { $0 })
        return allRecipes.filter { $0.categories.contains(.quick) && !excluded.contains($0.id) }
    }
    private var remaining: [Recipe] {
        let excluded = Set(created.map(\.id) + quick.map(\.id) + [featured?.id].compactMap { $0 })
        return allRecipes.filter { !excluded.contains($0.id) }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("Recipes")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                if let mealPlanSuggestion {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                        Text("Choose a recipe for \(mealPlanSuggestion.dayLabel)" +
                             (mealPlanSuggestion.slot.map { " · \($0.title)" } ?? ""))
                            .lineLimit(2)
                        Spacer(minLength: 5)
                        Button("Cancel") { cancelMealPlanSuggestion?() }
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.primaryGreen)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(AppTheme.chipBackground, in: RoundedRectangle(cornerRadius: 13))
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
                searchBar.padding(.horizontal, 16).padding(.top, 15)
                categoryChips.padding(.top, 16)

                if isSearching {
                    if searchResults.isEmpty {
                        emptyResults.padding(.top, 65)
                    } else {
                        verticalRecipes(searchResults)
                            .padding(.horizontal, 16)
                            .padding(.top, 22)
                    }
                } else {
                    if let featured {
                        sectionTitle("For You")
                            .padding(.horizontal, 16).padding(.top, 23)
                        FeaturedRecipeCard(recipe: featured)
                            .padding(.horizontal, 16).padding(.top, 15)
                    }
                    if !quick.isEmpty {
                        catalogSection("Quick & Easy", collection: .quickAndEasy, recipes: quick)
                    }
                    if !favorites.isEmpty {
                        catalogSection("Your Favorites", collection: .favorites, recipes: favorites)
                    }
                    if !created.isEmpty {
                        catalogSection("Created by You", collection: .createdByYou, recipes: created)
                    }
                    if !remaining.isEmpty {
                        catalogSection("More Recipes", collection: .moreRecipes, recipes: remaining)
                    }
                }
            }
            .padding(.bottom, 165)
        }
        .background(AppTheme.background)
        .overlay(alignment: .bottom) {
            Button { showingNewRecipe = true } label: {
                Label("Create a Recipe", systemImage: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 51)
                    .foregroundStyle(.white)
                    .background(AppTheme.primaryGreen, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 76)
            .accessibilityIdentifier("create-recipe-button")
        }
        .sheet(isPresented: $showingNewRecipe) {
            NavigationStack { RecipeEditorView() }
                .tint(AppTheme.primaryGreen)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func catalogSection(_ title: String, collection: RecipeCollection, recipes: [Recipe]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle(title)
                Spacer(minLength: 8)
                NavigationLink(value: collection) {
                    Text("See all")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.primaryGreen)
                }
                .accessibilityLabel("See all \(title) recipes")
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 13) {
                    ForEach(recipes) { recipe in
                        CompactRecipeCard(recipe: recipe, width: 158)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 28)
    }

    private func verticalRecipes(_ recipes: [Recipe]) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(recipes) { recipe in
                VerticalRecipeRow(recipe: recipe)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(Color.gray.opacity(0.82))
            TextField("Search", text: $searchText)
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("recipe-search")
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 14).padding(.trailing, 11)
        .frame(height: 48)
        .background(Capsule().fill(AppTheme.searchBackground))
        .overlay { Capsule().strokeBorder(.white.opacity(0.98), lineWidth: 1.1) }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecipeCategory.allCases) { category in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { selectedCategory = category }
                    } label: {
                        Text(category.rawValue)
                            .font(.system(size: 16, weight: selectedCategory == category ? .medium : .regular))
                            .foregroundStyle(selectedCategory == category ? .white : AppTheme.primaryText)
                            .frame(width: category.chipWidth, height: 47)
                            .background(Capsule().fill(selectedCategory == category ? AppTheme.primaryGreen : AppTheme.chipBackground))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 23, weight: .semibold))
            .foregroundStyle(AppTheme.primaryText)
    }

    private var emptyResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.secondaryText)
            Text("No matching recipes")
                .font(.system(size: 17, weight: .semibold))
            Text("Try another name, ingredient or filter.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
}
