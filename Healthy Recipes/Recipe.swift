//
//  Recipe.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import Foundation
import SwiftUI
import SwiftData

/// Plain UI value. The *only* persisted source of truth is StoredRecipe in SwiftData.
struct Recipe: Identifiable, Hashable {
    let id: String
    let title: String
    let minutes: Int
    let calories: Int?
    var imageName: String = "NoImage"
    let categories: Set<RecipeCategory>
    let ingredients: [RecipeIngredient]
    let steps: [String]
    let baseServings: Int
    var isUserCreated: Bool = false
    var isFavorite: Bool = false

    var caloriesText: String { calories.map { "~\($0) kcal" } ?? "Calories not provided" }
}

/// A stable ID allows one shopping-list entry per recipe ingredient.
struct RecipeIngredient: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var quantity: Double
    var unit: String

    init(id: String = UUID().uuidString, name: String, quantity: Double, unit: String) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }

    func scaled(for servings: Int, from baseServings: Int) -> Double {
        quantity * Double(servings) / Double(max(1, baseServings))
    }
}

enum QuantityText {
    static func format(_ amount: Double) -> String {
        amount.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func ingredient(_ item: RecipeIngredient, servings: Int, base: Int) -> String {
        let amount = format(item.scaled(for: servings, from: base))
        return "\(amount) \(item.unit) \(item.name)"
    }
}

enum RecipeCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case all = "All"
    case quick = "Quick"
    case highProtein = "High Protein"
    case pasta = "Pasta"
    case vegetarian = "Vegetarian"

    var id: String { rawValue }

    var chipWidth: CGFloat {
        switch self {
        case .all: 64
        case .quick: 86
        case .highProtein: 137
        case .pasta: 80
        case .vegetarian: 116
        }
    }
}

/// Catalog recipes AND user recipes share the same SwiftData model.
@Model
final class StoredRecipe {
    var id: String
    var title: String
    var minutes: Int
    var calories: Int?
    var imageName: String = "NoImage"
    var categoryNames: [String]
    var ingredientIDs: [String]
    var ingredientNames: [String]
    var ingredientQuantities: [Double]
    var ingredientUnits: [String]
    var steps: [String]
    var baseServings: Int
    // Legacy image bytes kept only to migrate existing user photos without data loss.
    @Attribute(.externalStorage) var photoData: Data?
    var isUserCreated: Bool
    var isFavorite: Bool
    var createdAt: Date

    init(id: String, title: String, minutes: Int, calories: Int?, imageName: String = "NoImage",
         categories: [RecipeCategory], ingredients: [RecipeIngredient], steps: [String],
         baseServings: Int = 1,
         isUserCreated: Bool = false, isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.minutes = minutes
        self.calories = calories
        self.imageName = imageName
        self.categoryNames = categories.map(\.rawValue)
        self.ingredientIDs = ingredients.map(\.id)
        self.ingredientNames = ingredients.map(\.name)
        self.ingredientQuantities = ingredients.map(\.quantity)
        self.ingredientUnits = ingredients.map(\.unit)
        self.steps = steps
        self.baseServings = max(1, baseServings)
        self.photoData = nil
        self.isUserCreated = isUserCreated
        self.isFavorite = isFavorite
        self.createdAt = .now
    }

    /// Stored directly as SwiftData arrays, with no JSON file or JSON serialization.
    var ingredients: [RecipeIngredient] {
        get {
            let count = min(ingredientIDs.count, ingredientNames.count,
                            ingredientQuantities.count, ingredientUnits.count)
            return (0..<count).map { index in
                RecipeIngredient(id: ingredientIDs[index], name: ingredientNames[index],
                    quantity: ingredientQuantities[index], unit: ingredientUnits[index])
            }
        }
        set {
            ingredientIDs = newValue.map(\.id)
            ingredientNames = newValue.map(\.name)
            ingredientQuantities = newValue.map(\.quantity)
            ingredientUnits = newValue.map(\.unit)
        }
    }

    var asRecipe: Recipe {
        Recipe(id: id, title: title, minutes: minutes, calories: calories,
               imageName: imageName,
               categories: Set(categoryNames.compactMap(RecipeCategory.init(rawValue:))),
               ingredients: ingredients, steps: steps, baseServings: baseServings,
               isUserCreated: isUserCreated, isFavorite: isFavorite)
    }
}

/// Shopping list also lives in the same local SwiftData database.
@Model
final class GroceryItem {
    var id: String
    var sourceRecipeID: String
    var ingredientID: String
    var recipeTitle: String
    var name: String
    var quantity: Double
    var unit: String
    var checked: Bool
    var addedAt: Date

    init(recipe: Recipe, ingredient: RecipeIngredient, servings: Int) {
        self.id = UUID().uuidString
        self.sourceRecipeID = recipe.id
        self.ingredientID = ingredient.id
        self.recipeTitle = recipe.title
        self.name = ingredient.name
        self.quantity = ingredient.scaled(for: servings, from: recipe.baseServings)
        self.unit = ingredient.unit
        self.checked = false
        self.addedAt = .now
    }
}
