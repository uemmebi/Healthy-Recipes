//
//  RecipeSeeds.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import Foundation
import SwiftData

@MainActor
enum RecipeSeeds {
    static func installIfNeeded(in context: ModelContext) {
        do {
            let existing = try context.fetch(FetchDescriptor<StoredRecipe>())
            let ids = Set(existing.map(\.id))
            for recipe in catalog() where !ids.contains(recipe.id) {
                context.insert(recipe)
            }

            // Optional one-time upgrade from the previous version's SwiftData model.
            // Keep the old model registered so users' own recipes are not lost.
            let previous = try context.fetch(FetchDescriptor<UserRecipe>())
            for old in previous where !ids.contains(old.id) {
                let ingredients = old.ingredientsText.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { RecipeIngredient(name: $0, quantity: 1, unit: "pcs") }
                let steps = old.stepsText.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let recovered = StoredRecipe(
                    id: old.id, title: old.title, minutes: old.minutes,
                    calories: old.calories, imageName: "",
                    categories: old.categoryNames.compactMap(RecipeCategory.init(rawValue:)),
                    ingredients: ingredients, steps: steps, photoData: old.photoData,
                    isUserCreated: true
                )
                context.insert(recovered)
            }
            try context.save()
        } catch {
            // Never fatalError inside preview: report issues in Xcode instead.
            print("SwiftData seed failed: \(error)")
        }
    }

    private static func item(_ name: String, _ amount: Double, _ unit: String) -> RecipeIngredient {
        RecipeIngredient(name: name, quantity: amount, unit: unit)
    }

    private static func catalog() -> [StoredRecipe] {
        [
            StoredRecipe(
                id: "catalog-salmon-bowl", title: "Salmon & Edamame Bowl", minutes: 35,
                calories: 690, imageName: "Poke", categories: [.highProtein],
                ingredients: [
                    item("salmon fillet", 240, "g"),
                    item("sushi rice (dry)", 120, "g"),
                    item("frozen shelled edamame", 120, "g"),
                    item("cucumber", 120, "g"),
                    item("carrot", 80, "g"),
                    item("avocado", 100, "g"),
                    item("low-sodium soy sauce", 20, "ml"),
                    item("rice vinegar", 10, "ml"),
                    item("sesame seeds", 8, "g"),
                    item("olive oil", 10, "ml")
                ],
                steps: [
                    "Wash your hands, then rinse the rice in a fine sieve under cool running water until the runoff is mostly clear. This removes excess surface starch.",
                    "Put the rice in a saucepan with the amount of water specified on the rice packet. Bring to a boil, reduce to a gentle simmer, cover, and cook until tender (usually 12–15 minutes).",
                    "Turn off the heat and let the rice stand covered for another 5 minutes. Fluff gently with a fork, then mix in the rice vinegar while it is warm.",
                    "Cook the frozen edamame in boiling water according to the package directions, usually 3–5 minutes. Drain and set aside. Do not eat edamame straight from the freezer.",
                    "Wash the cucumber and carrot. Thinly slice the cucumber and cut or grate the carrot into fine strips. Cut the avocado just before serving so it stays fresh.",
                    "Pat the salmon dry with kitchen paper. Check for pin bones, then cut into evenly sized large cubes. Keep raw fish separate from ready-to-eat vegetables.",
                    "Warm the olive oil in a non-stick pan over medium heat. Add the salmon in one layer and cook, turning carefully, until the pieces are golden and cooked through, around 6–9 minutes depending on thickness.",
                    "Check the thickest piece of salmon with a food thermometer: the center should reach 63°C (145°F), or be opaque and flake easily. Clean any tools that touched the raw fish.",
                    "Mix the soy sauce with 1 tablespoon water. Divide the rice evenly between two bowls and arrange the cooked salmon, edamame, cucumber, carrot and avocado over it.",
                    "Spoon over the soy dressing, sprinkle with the sesame seeds and serve immediately while the salmon is warm."
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-caprese", title: "Caprese Salad", minutes: 10,
                calories: 260, imageName: "Caprese", categories: [.quick, .vegetarian],
                ingredients: [
                    item("ripe tomatoes", 300, "g"),
                    item("fresh mozzarella", 125, "g"),
                    item("fresh basil leaves", 12, "leaves"),
                    item("extra-virgin olive oil", 15, "ml"),
                    item("balsamic vinegar (optional)", 10, "ml"),
                    item("sea salt", 2, "g"),
                    item("black pepper", 1, "g")
                ],
                steps: [
                    "Wash the tomatoes under cool running water and dry them with a clean towel. Rinse the basil leaves gently and pat them dry without bruising them.",
                    "Remove the tomato cores and slice the tomatoes into rounds about 5 mm thick. Keep slices similar in size so they are easy to layer.",
                    "Drain the mozzarella well. Pat it dry with kitchen paper, then cut it into rounds roughly the same thickness as the tomatoes.",
                    "Arrange alternating tomato and mozzarella slices on a serving platter, overlapping each slice slightly.",
                    "Tuck fresh basil leaves between the slices. Tear any large leaves with your hands rather than chopping them into tiny pieces.",
                    "Drizzle the extra-virgin olive oil evenly over the salad. Add the balsamic vinegar if you like a tangy finish.",
                    "Season lightly with sea salt and freshly ground black pepper just before serving. Taste a small bite before adding more salt.",
                    "Serve immediately, ideally at room temperature. If preparing ahead, keep it refrigerated and add the dressing only just before serving."
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-couscous", title: "Mediterranean Couscous", minutes: 15,
                calories: 430, imageName: "Couscous", categories: [.quick, .vegetarian],
                ingredients: [
                    item("couscous (dry)", 100, "g"),
                    item("low-salt vegetable stock", 150, "ml"),
                    item("cucumber", 100, "g"),
                    item("red bell pepper", 120, "g"),
                    item("spring onions", 2, "pcs"),
                    item("feta cheese", 50, "g"),
                    item("basil pesto", 25, "g"),
                    item("toasted sunflower seeds", 20, "g")
                ],
                steps: [
                    "Place the dry couscous in a large heatproof bowl. Heat the low-salt vegetable stock until it boils.",
                    "Pour the hot stock evenly over the couscous, stir once with a fork and cover with a plate or lid. Let it stand for 8–10 minutes, or according to the packet, until the liquid is absorbed.",
                    "Meanwhile, wash the cucumber, pepper and spring onions. Cut the cucumber into small cubes, remove the pepper's core and seeds and dice it, then thinly slice the spring onions.",
                    "Crumble the feta into bite-size pieces. If your sunflower seeds are not already toasted, warm them briefly in a dry frying pan, stirring until fragrant, then remove from the heat.",
                    "Uncover the couscous and fluff it gently with a fork, separating any clumps. Allow it to cool for 2 minutes so the raw vegetables stay crisp.",
                    "Stir the pesto into the warm couscous, making sure the grains are lightly coated. If needed, loosen the mixture with a spoonful of water.",
                    "Fold in the cucumber, pepper and spring onions. Mix gently so the vegetables are distributed evenly.",
                    "Divide between two bowls, scatter the feta and toasted sunflower seeds on top, and serve warm or at room temperature. Refrigerate leftovers promptly."
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-chickpeas", title: "Fresh Chickpea Salad", minutes: 15,
                calories: 320, imageName: "", categories: [.quick, .vegetarian],
                ingredients: [
                    item("cooked chickpeas, drained", 240, "g"),
                    item("cherry tomatoes", 200, "g"),
                    item("cucumber", 150, "g"),
                    item("red onion", 60, "g"),
                    item("fresh parsley", 15, "g"),
                    item("lemon juice", 30, "ml"),
                    item("extra-virgin olive oil", 15, "ml"),
                    item("ground cumin", 2, "g"),
                    item("sea salt", 2, "g")
                ],
                steps: [
                    "Drain the canned chickpeas into a colander, rinse thoroughly under cool water and leave to drain while you prepare the vegetables.",
                    "Wash the cherry tomatoes, cucumber and parsley. Halve the tomatoes, dice the cucumber into bite-size pieces and finely chop the parsley leaves.",
                    "Peel the red onion and dice it as finely as you can. If you prefer a milder taste, rinse the chopped onion in cold water for 30 seconds and pat dry.",
                    "Put the chickpeas in a large bowl. Crush a small spoonful lightly with a fork; their rough edges will help the dressing cling to the salad.",
                    "In a small bowl, whisk the lemon juice, olive oil, ground cumin and salt until combined.",
                    "Add the tomatoes, cucumber, onion and parsley to the chickpeas, pour over the dressing and fold everything together gently.",
                    "Taste, adjust the lemon or seasoning if needed, and leave the salad to sit for 5 minutes so the flavors mingle.",
                    "Serve on its own or alongside whole-grain bread. Refrigerate leftovers promptly in a covered container."
                ], baseServings: 2
            )
        ]
    }
}
