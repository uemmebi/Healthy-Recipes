//
//  RecipeCollection.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import SwiftUI
import SwiftData

enum RecipeCollection: String, Hashable {
    case quickAndEasy, favorites, createdByYou, moreRecipes

    var title: String {
        switch self {
        case .quickAndEasy: "Quick & Easy"
        case .favorites: "Your Favorites"
        case .createdByYou: "Created by You"
        case .moreRecipes: "More Recipes"
        }
    }
}

struct RecipeCollectionView: View {
    @Query private var records: [StoredRecipe]
    let collection: RecipeCollection

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var recipes: [Recipe] {
        let values = records.map(\.asRecipe)
        switch collection {
        case .quickAndEasy:
            return values.filter { !$0.isUserCreated && $0.categories.contains(.quick) }
        case .favorites:
            return values.filter(\.isFavorite)
        case .createdByYou:
            return values.filter(\.isUserCreated)
        case .moreRecipes:
            return values.filter { !$0.isUserCreated }
        }
    }

    var body: some View {
        ScrollView {
            if recipes.isEmpty {
                ContentUnavailableView("No recipes yet", systemImage: "book.closed",
                    description: Text("Save a favorite or add a recipe from the home screen."))
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(recipes) { recipe in
                        GeometryReader { geometry in
                            CompactRecipeCard(recipe: recipe, width: geometry.size.width)
                        }
                        .aspectRatio(0.78, contentMode: .fit)
                    }
                }
                .padding(16)
            }
        }
        .background(AppTheme.background)
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
    }
}
