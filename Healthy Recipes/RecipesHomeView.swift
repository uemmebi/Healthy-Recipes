//
//  RecipesHomeView.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import SwiftUI
import SwiftData

struct RecipesHomeView: View {
    @Query(sort: \StoredRecipe.createdAt, order: .forward) private var storedRecipes: [StoredRecipe]

    @State private var searchText = ""
    @State private var selectedCategory: RecipeCategory = .all
    @State private var showMicrophoneAlert = false
    @State private var showingNewRecipe = false

    private var allRecipes: [Recipe] { storedRecipes.map(\.asRecipe) }
    private var isFiltering: Bool {
        selectedCategory != .all || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func matches(_ recipe: Recipe) -> Bool {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchesText = term.isEmpty || recipe.title.localizedCaseInsensitiveContains(term)
        let matchesCategory = selectedCategory == .all || recipe.categories.contains(selectedCategory)
        return matchesText && matchesCategory
    }

    private var featured: Recipe? {
        guard !isFiltering else { return nil }
        return allRecipes.first { !$0.isUserCreated }
    }
    private var filteredCatalog: [Recipe] {
        guard isFiltering else { return [] }
        return allRecipes.filter { !$0.isUserCreated && matches($0) }
    }
    private var quickRecipes: [Recipe] {
        allRecipes.filter { !$0.isUserCreated && $0.categories.contains(.quick) && matches($0) }
    }
    private var createdRecipes: [Recipe] {
        allRecipes.filter { $0.isUserCreated && matches($0) }
    }
    private var favoriteRecipes: [Recipe] {
        allRecipes.filter { $0.isFavorite && matches($0) }
    }
    private var hasResults: Bool {
        featured != nil || !filteredCatalog.isEmpty || !quickRecipes.isEmpty || !createdRecipes.isEmpty || !favoriteRecipes.isEmpty
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Recipes")
                        .font(.system(size: 36, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer(minLength: 0)
                    Button { showingNewRecipe = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(AppTheme.primaryGreen)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Create recipe")
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                searchBar.padding(.horizontal, 16).padding(.top, 15)
                categoryChips.padding(.top, 16)

                if !hasResults && isFiltering {
                    emptyResults.padding(.top, 70)
                } else {
                    if let featured {
                        sectionTitle("For You")
                            .padding(.horizontal, 16).padding(.top, 15)
                        FeaturedRecipeCard(recipe: featured)
                            .padding(.horizontal, 16).padding(.top, 15)
                    }
                    // A filter affects the recipes, not the section headings.
                    // Show each catalog result once, rather than duplicating the featured card.
                    if !filteredCatalog.isEmpty {
                        sectionTitle("For You")
                            .padding(.horizontal, 16).padding(.top, 24)
                        recipeCarousel(filteredCatalog).padding(.top, 16)
                    }
                    if !quickRecipes.isEmpty && !isFiltering {
                        sectionHeading("Quick & Easy", collection: .quickAndEasy)
                            .padding(.horizontal, 16).padding(.top, 29)
                        recipeCarousel(quickRecipes).padding(.top, 17)
                    }
                    if !createdRecipes.isEmpty || !isFiltering {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            sectionTitle("Created by You")
                            Spacer(minLength: 4)
                            if !createdRecipes.isEmpty {
                                NavigationLink(value: RecipeCollection.createdByYou) {
                                    Text("See all").foregroundStyle(AppTheme.primaryGreen)
                                }
                            } else {
                                Button("Add recipe") { showingNewRecipe = true }
                                    .foregroundStyle(AppTheme.primaryGreen)
                            }
                        }
                        .font(.system(size: 16))
                        .padding(.horizontal, 16).padding(.top, 27)

                        if createdRecipes.isEmpty {
                            Button { showingNewRecipe = true } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 27))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Create your first recipe")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Add ingredients with amounts and cooking steps.")
                                            .font(.system(size: 13))
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(AppTheme.primaryGreen)
                                .padding(16)
                                .background(AppTheme.chipBackground, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16).padding(.top, 14)
                        } else {
                            recipeCarousel(createdRecipes).padding(.top, 17)
                        }
                    }
                    if !favoriteRecipes.isEmpty {
                        sectionHeading("Your Favorites", collection: .favorites)
                            .padding(.horizontal, 16).padding(.top, 27)
                        recipeCarousel(favoriteRecipes).padding(.top, 17)
                    }
                }
            }
            .padding(.bottom, 145)
        }
        .background(AppTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingNewRecipe) {
            NavigationStack { RecipeEditorView() }.tint(AppTheme.primaryGreen)
        }
        .alert("Voice Search", isPresented: $showMicrophoneAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Voice search is not yet available. You can search by typing.")
        }
    }

    private func recipeCarousel(_ recipes: [Recipe]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 13) {
                ForEach(recipes) { recipe in CompactRecipeCard(recipe: recipe) }
            }
            .padding(.horizontal, 16)
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
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.search)
            if searchText.isEmpty {
                Button { showMicrophoneAlert = true } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 21))
                        .foregroundStyle(Color.gray.opacity(0.82))
                        .frame(width: 30, height: 40)
                }
                .buttonStyle(.plain)
            } else {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
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
                            .font(.system(size: 16, weight: category == selectedCategory ? .medium : .regular))
                            .foregroundStyle(category == selectedCategory ? Color.white : AppTheme.primaryText)
                            .frame(width: category.chipWidth, height: 47)
                            .background(Capsule().fill(category == selectedCategory ? AppTheme.primaryGreen : AppTheme.chipBackground))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 23, weight: .semibold))
            .tracking(-0.35).foregroundStyle(AppTheme.primaryText)
    }

    private func sectionHeading(_ title: String, collection: RecipeCollection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            sectionTitle(title)
            Spacer(minLength: 4)
            NavigationLink(value: collection) {
                Text("See all").font(.system(size: 16)).foregroundStyle(AppTheme.primaryGreen)
            }
        }
    }

    private var emptyResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 35, weight: .light))
                .foregroundStyle(AppTheme.secondaryText)
            Text("No recipes found").font(.headline)
            Text("Try a different search or category.")
                .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 20)
    }
}
