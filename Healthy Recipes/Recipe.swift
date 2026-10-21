//
//  Recipe.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import Foundation
import SwiftUI
import SwiftData

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
    var proteinGrams: Double? = nil
    var carbsGrams: Double? = nil
    var fatGrams: Double? = nil
    var isUserCreated: Bool = false
    var isFavorite: Bool = false

    var caloriesText: String { calories.map { "~\($0) kcal" } ?? "Calories not provided" }
}

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

}

enum RecipeCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case all = "All"
    case quick = "Quick"
    case highProtein = "High Protein"
    case pasta = "Pasta"
    case vegetarian = "Vegetarian"
    case lowFat = "Low Fat"
    case highCarb = "High Carb"
    case lowCarb = "Low Carb"

    var id: String { rawValue }

    var chipWidth: CGFloat {
        switch self {
        case .all: 64
        case .quick: 86
        case .highProtein: 137
        case .lowFat: 104
        case .highCarb: 113
        case .lowCarb: 108
        case .pasta: 80
        case .vegetarian: 116
        }
    }
}

enum RecipeClassification {
    static func categories(minutes: Int, ingredients: [RecipeIngredient],
                           protein: Double?, carbs: Double?, fat: Double?,
                           chosen: Set<RecipeCategory>) -> Set<RecipeCategory> {
        var result = chosen.intersection([.vegetarian])
        if minutes < 20 { result.insert(.quick) }
        let pastaNames = #"\b(pasta|spaghetti|penne|fusilli|linguine|macaroni|farfalle|rigatoni|tagliatelle|fettuccine|lasagne|lasagna|orecchiette|tortellini)\b"#
        if ingredients.contains(where: { $0.name.range(of: pastaNames,
                                                       options: [.regularExpression, .caseInsensitive]) != nil }) {
            result.insert(.pasta)
        }
        if let protein, protein >= 25 { result.insert(.highProtein) }
        if let fat, fat <= 10 { result.insert(.lowFat) }
        if let carbs {
            if carbs >= 50 { result.insert(.highCarb) }
            if carbs <= 25 { result.insert(.lowCarb) }
        }
        return result
    }
}

@Model
final class StoredRecipe {
    var id: String
    var title: String
    var minutes: Int
    var calories: Int?
    var proteinGrams: Double? = nil
    var carbsGrams: Double? = nil
    var fatGrams: Double? = nil
    var imageName: String = "NoImage"
    var categoryNames: [String]
    var ingredientIDs: [String]
    var ingredientNames: [String]
    var ingredientQuantities: [Double]
    var ingredientUnits: [String]
    var steps: [String]
    var baseServings: Int
    var isUserCreated: Bool
    var isFavorite: Bool
    var createdAt: Date

    init(id: String, title: String, minutes: Int, calories: Int?, imageName: String = "NoImage",
         categories: [RecipeCategory], ingredients: [RecipeIngredient], steps: [String],
         baseServings: Int = 1,
         isUserCreated: Bool = false, isFavorite: Bool = false,
         proteinGrams: Double? = nil, carbsGrams: Double? = nil, fatGrams: Double? = nil) {
        self.id = id
        self.title = title
        self.minutes = minutes
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.imageName = imageName
        self.categoryNames = RecipeClassification.categories(
            minutes: minutes, ingredients: ingredients, protein: proteinGrams,
            carbs: carbsGrams, fat: fatGrams, chosen: Set(categories))
            .map(\.rawValue).sorted()
        self.ingredientIDs = ingredients.map(\.id)
        self.ingredientNames = ingredients.map(\.name)
        self.ingredientQuantities = ingredients.map(\.quantity)
        self.ingredientUnits = ingredients.map(\.unit)
        self.steps = steps
        self.baseServings = max(1, baseServings)
        self.isUserCreated = isUserCreated
        self.isFavorite = isFavorite
        self.createdAt = .now
    }

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
               categories: RecipeClassification.categories(
                   minutes: minutes, ingredients: ingredients, protein: proteinGrams,
                   carbs: carbsGrams, fat: fatGrams,
                   chosen: Set(categoryNames.compactMap(RecipeCategory.init(rawValue:)))),
               ingredients: ingredients, steps: steps, baseServings: baseServings,
               proteinGrams: proteinGrams, carbsGrams: carbsGrams, fatGrams: fatGrams,
               isUserCreated: isUserCreated, isFavorite: isFavorite)
    }
}

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
