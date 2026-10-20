//
//  RecipeSeeds.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import Foundation
import SwiftData

/// Seed catalog is written in Swift, not a bundled JSON file.
/// Catalog content is updated by stable ID, preserving favorites and personal recipes.
@MainActor
enum RecipeSeeds {
    static func installIfNeeded(in context: ModelContext) {
        do {
            let existing = try context.fetch(FetchDescriptor<StoredRecipe>())
            let existingByID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let allSeeds = catalog()

            // One-time conversion of existing user photos from Data? to filename String.
            // Keep the old photoData property in the schema for safe migration.
            for record in existing where record.isUserCreated && record.photoData != nil {
                if let bytes = record.photoData {
                    let newName = try RecipeImageStore.saveJPEGData(bytes)
                    record.imageName = newName
                    record.photoData = nil
                }
            }

            // The SwiftData record is the source of truth. Identifiers for shipped
            // ingredients are deterministic so grocery cart links survive app launches.
            for seed in allSeeds {
                seed.ingredients = seed.ingredients.enumerated().map { index, ingredient in
                    var stable = ingredient
                    stable.id = "\(seed.id)-ingredient-\(index)"
                    return stable
                }
                if let stored = existingByID[seed.id] {
                    guard !stored.isUserCreated else { continue }
                    // Refresh built-in catalog content while retaining favorites.
                    if stored.title != seed.title { stored.title = seed.title }
                    if stored.imageName != seed.imageName { stored.imageName = seed.imageName }
                    if stored.calories != seed.calories { stored.calories = seed.calories }
                    if stored.minutes != seed.minutes { stored.minutes = seed.minutes }
                    if stored.categoryNames != seed.categoryNames { stored.categoryNames = seed.categoryNames }
                    if stored.steps != seed.steps { stored.steps = seed.steps }
                    if stored.baseServings != seed.baseServings { stored.baseServings = seed.baseServings }
                    if stored.ingredients != seed.ingredients {
                        // Match existing grocery items by ingredient position to
                        // retain their relationship with the updated stable IDs.
                        let oldIngredients = stored.ingredients
                        let groceries = try context.fetch(FetchDescriptor<GroceryItem>())
                        for (index, item) in oldIngredients.enumerated() where index < seed.ingredients.count {
                            for grocery in groceries where grocery.sourceRecipeID == seed.id && grocery.ingredientID == item.id {
                                grocery.ingredientID = seed.ingredients[index].id
                            }
                        }
                        stored.ingredients = seed.ingredients
                    }
                } else {
                    context.insert(seed)
                }
            }

            // Remove the retired built-in Parmigiana only, not user-created recipes.
            for old in existing where !old.isUserCreated && (
                old.id == "catalog-parmigiana" ||
                old.title.localizedCaseInsensitiveContains("Parmigiana di melanzane")) {
                context.delete(old)
            }

            // Recover personal recipes created with the previous data model.
            let previous = try context.fetch(FetchDescriptor<UserRecipe>())
            for old in previous where existingByID[old.id] == nil {
                let oldIngredients = old.ingredientsText.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { RecipeIngredient(name: $0, quantity: 1, unit: "pcs") }
                let steps = old.stepsText.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let migratedName: String
                if let bytes = old.photoData {
                    migratedName = try RecipeImageStore.saveJPEGData(bytes)
                } else {
                    migratedName = RecipeImageStore.missingImageName
                }
                context.insert(StoredRecipe(
                    id: old.id, title: old.title, minutes: old.minutes,
                    calories: old.calories, imageName: migratedName,
                    categories: old.categoryNames.compactMap(RecipeCategory.init(rawValue:)),
                    ingredients: oldIngredients, steps: steps, baseServings: 1,
                    isUserCreated: true))
            }
            try context.save()
        } catch {
            print("SwiftData catalog update failed: \(error)")
        }
    }

    private static func item(_ name: String, _ amount: Double, _ unit: String) -> RecipeIngredient {
        RecipeIngredient(name: name, quantity: amount, unit: unit)
    }

    private static func catalog() -> [StoredRecipe] {
        initialCatalog() + additionalCatalog()
    }

    private static func initialCatalog() -> [StoredRecipe] {
        [
            StoredRecipe(
                id: "catalog-salmon-bowl", title: "Salmon & Edamame Bowl", minutes: 35,
                calories: 690, imageName: "Salmon & Edamame Bowl", categories: [.highProtein],
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
                calories: 260, imageName: "Caprese Salad", categories: [.quick, .vegetarian],
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
                calories: 430, imageName: "Mediterranean Couscous", categories: [.quick, .vegetarian],
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
                calories: 320, imageName: "Fresh Chickpea Salad", categories: [.quick, .vegetarian],
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
    // More curated recipes. Kept here so the whole catalog lives in one Swift file.
    private static func additionalCatalog() -> [StoredRecipe] {
        [
            StoredRecipe(
                id: "catalog-avocado-toast-with-eggs", title: "Avocado Toast with Eggs",
                minutes: 15, calories: 500, imageName: "Avocado Toast with Eggs",
                categories: [.quick, .highProtein, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "whole-grain bread", quantity: 4, unit: "slices"),
                    RecipeIngredient(name: "ripe avocado", quantity: 1, unit: "pcs"),
                    RecipeIngredient(name: "eggs", quantity: 4, unit: "pcs"),
                    RecipeIngredient(name: "lemon juice", quantity: 10, unit: "ml"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 5, unit: "ml"),
                    RecipeIngredient(name: "cherry tomatoes", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "black pepper", quantity: 1, unit: "g"),
                ],
                steps: [
                    "Wash the cherry tomatoes, halve them and set aside. Cut the avocado in half lengthwise and remove the stone carefully.",
                    "Scoop the avocado flesh into a bowl, add the lemon juice and mash with a fork until it is creamy but still slightly chunky.",
                    "Heat a non-stick frying pan over medium heat with the olive oil. Crack the eggs into the pan without breaking the yolks.",
                    "Cook the eggs until the whites are completely set, approximately 3–4 minutes. For firmer yolks, cover the pan and cook a little longer.",
                    "Toast the whole-grain bread until golden and crisp. Place the slices on two plates while still warm.",
                    "Spread the avocado evenly over the toast, add the cooked eggs and tomatoes, then finish with freshly ground pepper and serve immediately.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-overnight-oats", title: "Overnight Oats",
                minutes: 10, calories: 360, imageName: "Overnight Oats",
                categories: [.quick, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "rolled oats", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "milk or unsweetened plant milk", quantity: 240, unit: "ml"),
                    RecipeIngredient(name: "plain Greek yogurt", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "chia seeds", quantity: 20, unit: "g"),
                    RecipeIngredient(name: "blueberries", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "banana", quantity: 1, unit: "pcs"),
                    RecipeIngredient(name: "ground cinnamon", quantity: 2, unit: "g"),
                ],
                steps: [
                    "Set out two clean jars or airtight containers and divide the rolled oats evenly between them.",
                    "Add half the milk and Greek yogurt to each jar, then stir until the oats are thoroughly moistened.",
                    "Mix in the chia seeds and cinnamon, checking that no dry seeds are clumped at the bottom.",
                    "Cover both jars and refrigerate for at least 4 hours, ideally overnight, so the oats soften and thicken safely.",
                    "The next morning, stir the mixture and add a little extra milk if the texture is too thick to spoon easily.",
                    "Wash the blueberries, slice the banana just before eating and place the fruit on top of the oats. Serve chilled.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-greek-yogurt-parfait", title: "Greek Yogurt Parfait",
                minutes: 10, calories: 330, imageName: "Greek Yogurt Parfait",
                categories: [.quick, .highProtein, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "plain Greek yogurt", quantity: 350, unit: "g"),
                    RecipeIngredient(name: "strawberries", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "blueberries", quantity: 80, unit: "g"),
                    RecipeIngredient(name: "rolled oats", quantity: 40, unit: "g"),
                    RecipeIngredient(name: "walnuts", quantity: 25, unit: "g"),
                    RecipeIngredient(name: "honey", quantity: 10, unit: "g"),
                ],
                steps: [
                    "Rinse the strawberries and blueberries under cool running water, then dry them carefully with kitchen paper.",
                    "Remove the green tops from the strawberries and slice them into bite-sized pieces.",
                    "Roughly chop the walnuts, checking for any hard shell fragments before adding them to the bowls.",
                    "Place a spoonful of Greek yogurt in the bottom of each of two glasses or small bowls.",
                    "Add layers of berries and rolled oats, then repeat with the remaining yogurt so each serving has distinct layers.",
                    "Scatter the chopped walnuts over the top, drizzle lightly with honey and serve immediately to keep the oats slightly crunchy.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-chia-seed-pudding", title: "Chia Seed Pudding",
                minutes: 10, calories: 230, imageName: "Chia Seed Pudding",
                categories: [.quick, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "chia seeds", quantity: 50, unit: "g"),
                    RecipeIngredient(name: "unsweetened almond milk", quantity: 300, unit: "ml"),
                    RecipeIngredient(name: "plain Greek yogurt", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "raspberries", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "maple syrup", quantity: 10, unit: "ml"),
                    RecipeIngredient(name: "vanilla extract", quantity: 2, unit: "ml"),
                ],
                steps: [
                    "Measure the chia seeds into a mixing bowl and pour in the almond milk, whisking thoroughly to distribute the seeds.",
                    "Stir in the vanilla and maple syrup until everything is evenly mixed and no dry pockets of seeds remain.",
                    "Leave the mixture for 10 minutes, then whisk again to break up any clumps forming as the seeds swell.",
                    "Transfer the mixture into two containers, cover and refrigerate for at least 3 hours or overnight until thick.",
                    "Rinse the raspberries gently and allow excess water to drain so the fruit does not water down the pudding.",
                    "Divide the Greek yogurt over the two puddings, top with raspberries and serve cold with a spoon.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-banana-oat-pancakes", title: "Banana Oat Pancakes",
                minutes: 20, calories: 370, imageName: "Banana Oat Pancakes",
                categories: [.vegetarian],
                ingredients: [
                    RecipeIngredient(name: "ripe bananas", quantity: 2, unit: "pcs"),
                    RecipeIngredient(name: "eggs", quantity: 2, unit: "pcs"),
                    RecipeIngredient(name: "rolled oats", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "milk", quantity: 60, unit: "ml"),
                    RecipeIngredient(name: "baking powder", quantity: 4, unit: "g"),
                    RecipeIngredient(name: "ground cinnamon", quantity: 2, unit: "g"),
                    RecipeIngredient(name: "olive oil", quantity: 5, unit: "ml"),
                ],
                steps: [
                    "Blend the rolled oats until they form a coarse flour, then pour the flour into a mixing bowl.",
                    "Peel and mash the bananas thoroughly with a fork until only a few small lumps remain.",
                    "Beat the eggs in a separate bowl and mix them with the banana, milk and cinnamon until combined.",
                    "Fold in the oat flour and baking powder, then rest the batter for 5 minutes while the oats absorb moisture.",
                    "Lightly oil a non-stick frying pan over medium-low heat and spoon in small rounds of batter, leaving space between them.",
                    "Cook each pancake until small bubbles appear and the underside is golden, about 2 minutes, then flip and cook 1–2 minutes more until set throughout.",
                    "Continue with the remaining batter and serve the pancakes warm. Keep cooked pancakes covered while finishing the batch.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-green-smoothie", title: "Green Smoothie",
                minutes: 10, calories: 185, imageName: "Green Smoothie",
                categories: [.quick, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "fresh baby spinach", quantity: 60, unit: "g"),
                    RecipeIngredient(name: "ripe bananas", quantity: 2, unit: "pcs"),
                    RecipeIngredient(name: "kiwi fruits", quantity: 2, unit: "pcs"),
                    RecipeIngredient(name: "unsweetened yogurt", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "cold water", quantity: 250, unit: "ml"),
                    RecipeIngredient(name: "lemon juice", quantity: 15, unit: "ml"),
                ],
                steps: [
                    "Wash the baby spinach thoroughly under running water and drain it to remove any grit.",
                    "Peel the bananas and kiwi fruits, then cut them into chunks that will fit easily into your blender.",
                    "Put the water in the blender first, followed by the yogurt, spinach, banana, kiwi and lemon juice.",
                    "Blend on low speed for a few seconds, then increase to high and process until the mixture looks smooth.",
                    "Check the texture and add a small splash of cold water if it is too thick to pour comfortably.",
                    "Taste for balance, divide between two glasses and serve immediately while cold and fresh.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-quinoa-salad", title: "Quinoa Salad",
                minutes: 30, calories: 400, imageName: "Quinoa Salad",
                categories: [.quick, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "dry quinoa", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "water", quantity: 240, unit: "ml"),
                    RecipeIngredient(name: "cucumber", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "cherry tomatoes", quantity: 160, unit: "g"),
                    RecipeIngredient(name: "cooked chickpeas", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "fresh parsley", quantity: 15, unit: "g"),
                    RecipeIngredient(name: "lemon juice", quantity: 25, unit: "ml"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 15, unit: "ml"),
                ],
                steps: [
                    "Rinse the quinoa thoroughly in a fine sieve under cold running water to remove any bitter coating.",
                    "Put the quinoa and water in a saucepan, bring to a boil, cover and simmer gently for 12–15 minutes until the grains are tender.",
                    "Remove the saucepan from the heat and leave covered for 5 minutes. Fluff the quinoa with a fork and spread it out to cool slightly.",
                    "Wash and dice the cucumber, halve the tomatoes and finely chop the parsley, removing any tough stems.",
                    "Drain and rinse the cooked chickpeas, then combine them with the cooled quinoa and prepared vegetables.",
                    "Whisk the lemon juice and olive oil in a small bowl, pour over the salad and toss gently until every ingredient is coated.",
                    "Taste and adjust with extra lemon if desired, then divide into bowls and refrigerate any leftovers promptly.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-greek-salad", title: "Greek Salad",
                minutes: 15, calories: 340, imageName: "Greek Salad",
                categories: [.quick, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "ripe tomatoes", quantity: 300, unit: "g"),
                    RecipeIngredient(name: "cucumber", quantity: 200, unit: "g"),
                    RecipeIngredient(name: "red onion", quantity: 70, unit: "g"),
                    RecipeIngredient(name: "green bell pepper", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "feta cheese", quantity: 90, unit: "g"),
                    RecipeIngredient(name: "Kalamata olives", quantity: 60, unit: "g"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 20, unit: "ml"),
                    RecipeIngredient(name: "dried oregano", quantity: 2, unit: "g"),
                ],
                steps: [
                    "Wash the tomatoes, cucumber and bell pepper under cool water and dry them with a clean towel.",
                    "Cut the tomatoes into bite-sized wedges, slice the cucumber into thick half-moons and remove the pepper seeds before cutting into strips.",
                    "Peel the red onion and slice it thinly; soak the slices briefly in cold water if you prefer a less sharp flavor.",
                    "Transfer the prepared vegetables into a large shallow salad bowl and gently toss to distribute them evenly.",
                    "Add the olives, then place the feta on top in larger pieces so it does not completely crumble into the salad.",
                    "Drizzle evenly with olive oil, sprinkle with dried oregano and serve straight away without overdressing the vegetables.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-chicken-caesar-salad", title: "Chicken Caesar Salad",
                minutes: 30, calories: 465, imageName: "Chicken Caesar Salad",
                categories: [.highProtein],
                ingredients: [
                    RecipeIngredient(name: "boneless chicken breast", quantity: 300, unit: "g"),
                    RecipeIngredient(name: "romaine lettuce", quantity: 250, unit: "g"),
                    RecipeIngredient(name: "plain Greek yogurt", quantity: 80, unit: "g"),
                    RecipeIngredient(name: "lemon juice", quantity: 20, unit: "ml"),
                    RecipeIngredient(name: "Dijon mustard", quantity: 10, unit: "g"),
                    RecipeIngredient(name: "parmesan cheese", quantity: 30, unit: "g"),
                    RecipeIngredient(name: "whole-grain bread", quantity: 2, unit: "slices"),
                    RecipeIngredient(name: "olive oil", quantity: 15, unit: "ml"),
                ],
                steps: [
                    "Wash the romaine lettuce thoroughly, spin or pat it dry, then tear the leaves into bite-sized pieces and refrigerate until needed.",
                    "Cut the bread into small cubes and toss with one third of the olive oil. Toast in an oven at 190°C for 8–10 minutes until crisp.",
                    "Mix the Greek yogurt, lemon juice and Dijon mustard in a bowl to make a lighter Caesar-style dressing; thin with a spoonful of water if needed.",
                    "Pat the chicken dry with kitchen paper and keep the uncooked meat away from the prepared salad and dressing.",
                    "Heat the remaining oil in a pan over medium heat, cook the chicken on both sides and check the thickest part reaches 74°C (165°F).",
                    "Transfer the cooked chicken to a clean board, rest for 3 minutes and slice into even strips.",
                    "Toss the lettuce with the dressing, divide between two plates, top with chicken, croutons and grated parmesan, and serve.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-grilled-chicken-and-vegetables", title: "Grilled Chicken and Vegetables",
                minutes: 35, calories: 420, imageName: "Grilled Chicken and Vegetables",
                categories: [.highProtein],
                ingredients: [
                    RecipeIngredient(name: "boneless chicken breast", quantity: 320, unit: "g"),
                    RecipeIngredient(name: "zucchini", quantity: 200, unit: "g"),
                    RecipeIngredient(name: "red bell pepper", quantity: 160, unit: "g"),
                    RecipeIngredient(name: "broccoli florets", quantity: 180, unit: "g"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 20, unit: "ml"),
                    RecipeIngredient(name: "lemon juice", quantity: 20, unit: "ml"),
                    RecipeIngredient(name: "smoked paprika", quantity: 3, unit: "g"),
                    RecipeIngredient(name: "dried oregano", quantity: 2, unit: "g"),
                ],
                steps: [
                    "Preheat the oven to 200°C and line a baking tray with baking paper for easier cleanup.",
                    "Wash the zucchini, pepper and broccoli, then cut them into pieces of roughly equal size for even cooking.",
                    "Toss the vegetables with half the olive oil, oregano and smoked paprika, spreading them into one even layer on the tray.",
                    "Roast the vegetables for 18–22 minutes, turning once, until tender and slightly browned at the edges.",
                    "While they roast, pat the chicken dry, rub it with the remaining oil and a little paprika, and heat a grill pan over medium heat.",
                    "Cook the chicken for approximately 6–8 minutes per side, depending on thickness, until a thermometer inserted in the center reads 74°C (165°F).",
                    "Rest the chicken on a clean plate for 3 minutes, slice it, arrange beside the vegetables and finish with lemon juice.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-chicken-stir-fry", title: "Chicken Stir Fry",
                minutes: 25, calories: 390, imageName: "Chicken Stir Fry",
                categories: [.quick, .highProtein],
                ingredients: [
                    RecipeIngredient(name: "boneless chicken breast", quantity: 300, unit: "g"),
                    RecipeIngredient(name: "broccoli florets", quantity: 200, unit: "g"),
                    RecipeIngredient(name: "red bell pepper", quantity: 140, unit: "g"),
                    RecipeIngredient(name: "carrot", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "low-sodium soy sauce", quantity: 25, unit: "ml"),
                    RecipeIngredient(name: "fresh ginger", quantity: 12, unit: "g"),
                    RecipeIngredient(name: "garlic", quantity: 2, unit: "cloves"),
                    RecipeIngredient(name: "sesame oil", quantity: 10, unit: "ml"),
                    RecipeIngredient(name: "cooked brown rice", quantity: 250, unit: "g"),
                ],
                steps: [
                    "Wash the broccoli, pepper and carrot, then cut everything into thin, similarly sized pieces so they cook quickly.",
                    "Peel and finely grate the ginger and garlic, and mix them with the low-sodium soy sauce and two tablespoons of water.",
                    "Slice the chicken into thin strips on a separate board, then wash your hands and clean the board and knife before handling anything else.",
                    "Heat half the sesame oil in a large frying pan or wok over medium-high heat and brown the chicken in a single layer.",
                    "Continue cooking until the chicken is fully cooked and the thickest pieces reach 74°C (165°F), then move it to a clean bowl.",
                    "Add the remaining oil and stir-fry the vegetables for 4–6 minutes, keeping them moving until just tender with some bite.",
                    "Return the chicken to the pan, pour in the ginger-soy sauce and stir for 1–2 minutes until everything is coated and steaming.",
                    "Warm the pre-cooked brown rice thoroughly according to its package, divide into bowls and spoon the stir-fry over it.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-baked-salmon-with-vegetables", title: "Baked Salmon with Vegetables",
                minutes: 35, calories: 470, imageName: "Baked Salmon with Vegetables",
                categories: [.highProtein],
                ingredients: [
                    RecipeIngredient(name: "salmon fillets", quantity: 300, unit: "g"),
                    RecipeIngredient(name: "baby potatoes", quantity: 250, unit: "g"),
                    RecipeIngredient(name: "asparagus", quantity: 200, unit: "g"),
                    RecipeIngredient(name: "cherry tomatoes", quantity: 160, unit: "g"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 20, unit: "ml"),
                    RecipeIngredient(name: "lemon", quantity: 1, unit: "pcs"),
                    RecipeIngredient(name: "garlic", quantity: 2, unit: "cloves"),
                    RecipeIngredient(name: "dried dill", quantity: 2, unit: "g"),
                ],
                steps: [
                    "Preheat the oven to 200°C. Wash the baby potatoes, halve larger ones and place them in a roasting dish.",
                    "Toss the potatoes with half the olive oil and roast for 15 minutes before adding the quicker-cooking ingredients.",
                    "Rinse the asparagus and tomatoes, snap off tough asparagus ends, and peel and finely chop the garlic.",
                    "Pat the salmon dry and place it on a separate clean surface. Keep fish juices away from ready-to-eat vegetables.",
                    "Remove the tray carefully, push the potatoes aside and add the asparagus, tomatoes and salmon fillets.",
                    "Drizzle with the remaining oil, add garlic and dill, then lay thin slices of lemon on the salmon.",
                    "Return the tray to the oven for around 12–15 minutes, adjusting for the thickness of the fish and vegetables.",
                    "Check the thickest part of the fish reaches 63°C (145°F). Serve the salmon with the roasted vegetables and lemon wedges.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-tuna-and-white-bean-salad", title: "Tuna and White Bean Salad",
                minutes: 15, calories: 370, imageName: "Tuna and White Bean Salad",
                categories: [.quick, .highProtein],
                ingredients: [
                    RecipeIngredient(name: "canned tuna in water, drained", quantity: 200, unit: "g"),
                    RecipeIngredient(name: "cooked cannellini beans", quantity: 240, unit: "g"),
                    RecipeIngredient(name: "cherry tomatoes", quantity: 180, unit: "g"),
                    RecipeIngredient(name: "red onion", quantity: 50, unit: "g"),
                    RecipeIngredient(name: "fresh parsley", quantity: 15, unit: "g"),
                    RecipeIngredient(name: "lemon juice", quantity: 25, unit: "ml"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 15, unit: "ml"),
                    RecipeIngredient(name: "baby spinach", quantity: 70, unit: "g"),
                ],
                steps: [
                    "Drain the tuna thoroughly and flake it into large pieces using a fork; check that no hard fragments are present.",
                    "Drain the cannellini beans, rinse under running water and shake away excess liquid in a sieve.",
                    "Wash and halve the cherry tomatoes, then peel the red onion and cut it into very fine slices.",
                    "Rinse the spinach and parsley, dry them well and roughly chop the parsley leaves.",
                    "Whisk together the lemon juice and olive oil in a separate small bowl until the dressing looks combined.",
                    "Combine beans, tomatoes, onion and parsley, fold in the tuna gently and pour over the dressing.",
                    "Serve over a bed of baby spinach and refrigerate any leftovers promptly in an airtight container.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-turkey-lettuce-wraps", title: "Turkey Lettuce Wraps",
                minutes: 25, calories: 310, imageName: "Turkey Lettuce Wraps",
                categories: [.quick, .highProtein],
                ingredients: [
                    RecipeIngredient(name: "lean ground turkey", quantity: 300, unit: "g"),
                    RecipeIngredient(name: "large lettuce leaves", quantity: 8, unit: "leaves"),
                    RecipeIngredient(name: "carrot", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "cucumber", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "spring onions", quantity: 2, unit: "pcs"),
                    RecipeIngredient(name: "low-sodium soy sauce", quantity: 20, unit: "ml"),
                    RecipeIngredient(name: "fresh ginger", quantity: 10, unit: "g"),
                    RecipeIngredient(name: "olive oil", quantity: 10, unit: "ml"),
                ],
                steps: [
                    "Wash the lettuce carefully, separate eight large leaves and pat them dry so they will hold the filling.",
                    "Wash and finely dice the carrot and cucumber, then thinly slice the spring onions and grate the fresh ginger.",
                    "Heat the olive oil in a non-stick pan over medium heat and add the ground turkey, breaking it up with a spoon.",
                    "Cook the turkey until browned all over and a food thermometer confirms it has reached 74°C (165°F).",
                    "Add the grated ginger, spring onions and soy sauce, then cook for another 2 minutes while stirring constantly.",
                    "Remove the pan from the heat and let the mixture cool slightly so it will not wilt the lettuce immediately.",
                    "Spoon the turkey into the lettuce leaves, scatter with carrot and cucumber, then roll or fold each leaf and serve.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-vegetable-omelette", title: "Vegetable Omelette",
                minutes: 20, calories: 290, imageName: "Vegetable Omelette",
                categories: [.quick, .highProtein, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "eggs", quantity: 4, unit: "pcs"),
                    RecipeIngredient(name: "baby spinach", quantity: 70, unit: "g"),
                    RecipeIngredient(name: "cherry tomatoes", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "mushrooms", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "milk", quantity: 30, unit: "ml"),
                    RecipeIngredient(name: "olive oil", quantity: 10, unit: "ml"),
                    RecipeIngredient(name: "feta cheese", quantity: 40, unit: "g"),
                ],
                steps: [
                    "Wash the spinach and tomatoes, slice the mushrooms and halve the tomatoes before turning on the heat.",
                    "Crack the eggs into a bowl, pour in the milk and whisk with a fork until the yolks and whites are combined.",
                    "Heat half the olive oil in a non-stick pan, add the mushrooms and cook for 4 minutes until any moisture evaporates.",
                    "Add the spinach and tomatoes and cook for another 1–2 minutes until the leaves wilt, then transfer the vegetables to a plate.",
                    "Pour the remaining oil into the pan, add the eggs and cook gently, lifting the edges so uncooked egg can flow underneath.",
                    "When the omelette is nearly set, scatter the vegetables and crumbled feta over one half, then fold carefully.",
                    "Cook until the egg is fully set, slide onto a plate, halve between two servings and eat immediately.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-lentil-soup", title: "Lentil Soup",
                minutes: 45, calories: 340, imageName: "Lentil Soup",
                categories: [.vegetarian],
                ingredients: [
                    RecipeIngredient(name: "dry red lentils", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "carrot", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "celery stalks", quantity: 2, unit: "pcs"),
                    RecipeIngredient(name: "yellow onion", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "garlic", quantity: 2, unit: "cloves"),
                    RecipeIngredient(name: "chopped tomatoes", quantity: 200, unit: "g"),
                    RecipeIngredient(name: "low-salt vegetable stock", quantity: 700, unit: "ml"),
                    RecipeIngredient(name: "olive oil", quantity: 15, unit: "ml"),
                    RecipeIngredient(name: "ground cumin", quantity: 3, unit: "g"),
                ],
                steps: [
                    "Rinse the red lentils in a fine sieve under cool running water until the runoff is clear, then drain thoroughly.",
                    "Peel and finely dice the onion, carrots and celery; peel the garlic and chop it into small pieces.",
                    "Warm the olive oil in a heavy saucepan over medium heat and cook the onion, carrot and celery for 6–8 minutes until softened.",
                    "Stir in the garlic and ground cumin for 30 seconds until fragrant, taking care not to let the garlic brown.",
                    "Add the rinsed lentils, chopped tomatoes and vegetable stock. Stir well and bring to a gentle boil.",
                    "Lower the heat and simmer uncovered for 20–25 minutes, stirring occasionally, until the lentils are very soft.",
                    "Blend part of the soup for a creamier texture if desired, keeping the blender away from boiling splashes.",
                    "Taste, adjust the seasoning if needed and serve hot. Cool and refrigerate leftovers promptly in shallow containers.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-spinach-and-chickpea-curry", title: "Spinach and Chickpea Curry",
                minutes: 35, calories: 430, imageName: "Spinach and Chickpea Curry",
                categories: [.vegetarian],
                ingredients: [
                    RecipeIngredient(name: "cooked chickpeas", quantity: 300, unit: "g"),
                    RecipeIngredient(name: "baby spinach", quantity: 180, unit: "g"),
                    RecipeIngredient(name: "chopped tomatoes", quantity: 250, unit: "g"),
                    RecipeIngredient(name: "onion", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "garlic", quantity: 2, unit: "cloves"),
                    RecipeIngredient(name: "fresh ginger", quantity: 12, unit: "g"),
                    RecipeIngredient(name: "light coconut milk", quantity: 200, unit: "ml"),
                    RecipeIngredient(name: "curry powder", quantity: 8, unit: "g"),
                    RecipeIngredient(name: "olive oil", quantity: 10, unit: "ml"),
                ],
                steps: [
                    "Drain and rinse the chickpeas, wash the spinach and prepare the onion, garlic and ginger by peeling and chopping finely.",
                    "Warm the olive oil in a deep pan over medium heat and cook the onion for 5 minutes until translucent.",
                    "Add the garlic, ginger and curry powder and cook for 30 seconds, stirring so the spices become fragrant without burning.",
                    "Pour in the chopped tomatoes and coconut milk, stir thoroughly and bring to a gentle simmer.",
                    "Add the chickpeas and cook for 12–15 minutes so they warm through and absorb the flavors of the sauce.",
                    "Stir in the spinach in handfuls, allowing each handful to wilt before adding more until all the leaves are tender.",
                    "Taste the sauce, simmer for another 2 minutes if it needs thickening, and serve the curry piping hot.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-tofu-stir-fry", title: "Tofu Stir Fry",
                minutes: 25, calories: 360, imageName: "Tofu Stir Fry",
                categories: [.quick, .vegetarian, .highProtein],
                ingredients: [
                    RecipeIngredient(name: "firm tofu", quantity: 300, unit: "g"),
                    RecipeIngredient(name: "broccoli florets", quantity: 180, unit: "g"),
                    RecipeIngredient(name: "red bell pepper", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "carrot", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "low-sodium soy sauce", quantity: 25, unit: "ml"),
                    RecipeIngredient(name: "fresh ginger", quantity: 10, unit: "g"),
                    RecipeIngredient(name: "garlic", quantity: 2, unit: "cloves"),
                    RecipeIngredient(name: "sesame oil", quantity: 15, unit: "ml"),
                    RecipeIngredient(name: "sesame seeds", quantity: 10, unit: "g"),
                ],
                steps: [
                    "Drain the tofu, wrap it in a clean cloth and press it gently under a plate for 10 minutes to remove excess water.",
                    "Cut the tofu into 2 cm cubes, then wash the broccoli, pepper and carrot and slice the vegetables into small pieces.",
                    "Mix the low-sodium soy sauce with the grated ginger, chopped garlic and two tablespoons of water.",
                    "Heat half the sesame oil in a non-stick pan and cook the tofu for 5–7 minutes, turning carefully until golden on several sides.",
                    "Transfer the tofu to a plate, add the remaining oil and stir-fry the vegetables over medium-high heat for 4–6 minutes.",
                    "Return the tofu to the pan, pour in the soy mixture and cook for another 2 minutes so the sauce coats everything.",
                    "Scatter the sesame seeds over the stir-fry and divide evenly between two bowls while hot.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-vegetable-buddha-bowl", title: "Vegetable Buddha Bowl",
                minutes: 35, calories: 480, imageName: "Vegetable Buddha Bowl",
                categories: [.vegetarian],
                ingredients: [
                    RecipeIngredient(name: "dry quinoa", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "sweet potato", quantity: 250, unit: "g"),
                    RecipeIngredient(name: "cooked chickpeas", quantity: 180, unit: "g"),
                    RecipeIngredient(name: "baby spinach", quantity: 80, unit: "g"),
                    RecipeIngredient(name: "red cabbage", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "ripe avocado", quantity: 1, unit: "pcs"),
                    RecipeIngredient(name: "tahini", quantity: 30, unit: "g"),
                    RecipeIngredient(name: "lemon juice", quantity: 25, unit: "ml"),
                    RecipeIngredient(name: "olive oil", quantity: 15, unit: "ml"),
                ],
                steps: [
                    "Preheat the oven to 200°C. Peel the sweet potato, cut it into even cubes and toss with the olive oil.",
                    "Spread the sweet potato on a baking tray and roast for 20–25 minutes, turning once, until soft in the center and browned at the edges.",
                    "Rinse the quinoa thoroughly, then simmer in twice its volume of water until tender, about 12–15 minutes, and let it rest covered.",
                    "Drain and rinse the chickpeas, then wash the spinach and finely shred the red cabbage.",
                    "Whisk the tahini with lemon juice and a small splash of water until you have a smooth, pourable dressing.",
                    "Halve the avocado, remove the stone carefully, scoop out the flesh and cut it into slices just before serving.",
                    "Arrange quinoa, roasted sweet potato, chickpeas, spinach, cabbage and avocado in two bowls and drizzle with tahini dressing.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-sweet-potato-and-black-bean-bowl", title: "Sweet Potato and Black Bean Bowl",
                minutes: 40, calories: 510, imageName: "Sweet Potato and Black Bean Bowl",
                categories: [.vegetarian],
                ingredients: [
                    RecipeIngredient(name: "sweet potatoes", quantity: 350, unit: "g"),
                    RecipeIngredient(name: "cooked black beans", quantity: 260, unit: "g"),
                    RecipeIngredient(name: "brown rice (dry)", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "red bell pepper", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "ripe avocado", quantity: 1, unit: "pcs"),
                    RecipeIngredient(name: "lime juice", quantity: 25, unit: "ml"),
                    RecipeIngredient(name: "olive oil", quantity: 15, unit: "ml"),
                    RecipeIngredient(name: "ground cumin", quantity: 4, unit: "g"),
                ],
                steps: [
                    "Preheat the oven to 200°C, wash the sweet potatoes and cut them into small, evenly sized pieces.",
                    "Coat the sweet potatoes with the olive oil and cumin, then roast on a lined tray for about 25 minutes until tender.",
                    "Rinse the brown rice, cook in water according to the packet, then cover and let it rest for 5 minutes before fluffing.",
                    "Drain and rinse the black beans, warm them through in a small saucepan with a splash of water and stir occasionally.",
                    "Wash the pepper and cut it into strips, then slice the avocado carefully and squeeze the lime juice over it.",
                    "Divide the rice between two bowls, add sweet potatoes, beans, pepper and avocado in separate sections.",
                    "Finish with any remaining lime juice and serve warm, adding a little water to the beans if they seem dry.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-hummus-and-veggie-sticks", title: "Hummus and Veggie Sticks",
                minutes: 15, calories: 260, imageName: "Hummus and Veggie Sticks",
                categories: [.quick, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "cooked chickpeas", quantity: 240, unit: "g"),
                    RecipeIngredient(name: "tahini", quantity: 30, unit: "g"),
                    RecipeIngredient(name: "lemon juice", quantity: 25, unit: "ml"),
                    RecipeIngredient(name: "garlic", quantity: 1, unit: "cloves"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 15, unit: "ml"),
                    RecipeIngredient(name: "carrots", quantity: 180, unit: "g"),
                    RecipeIngredient(name: "cucumber", quantity: 180, unit: "g"),
                    RecipeIngredient(name: "red bell pepper", quantity: 150, unit: "g"),
                ],
                steps: [
                    "Drain and rinse the chickpeas in a sieve, allowing the excess water to run off completely.",
                    "Place the chickpeas, tahini, lemon juice, peeled garlic and half the olive oil in a blender or food processor.",
                    "Blend until smooth, adding cold water one tablespoon at a time until the hummus is creamy and spreadable.",
                    "Taste the hummus and add more lemon if you prefer a brighter flavor, then transfer it to a serving bowl.",
                    "Wash and peel the carrots if needed, then cut the carrots, cucumber and pepper into similar-sized dipping sticks.",
                    "Drizzle the hummus with the remaining olive oil and serve beside the vegetables. Refrigerate leftovers promptly.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-zucchini-noodles-with-pesto", title: "Zucchini Noodles with Pesto",
                minutes: 20, calories: 300, imageName: "Zucchini Noodles with Pesto",
                categories: [.quick, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "zucchini", quantity: 400, unit: "g"),
                    RecipeIngredient(name: "fresh basil", quantity: 30, unit: "g"),
                    RecipeIngredient(name: "pine nuts", quantity: 25, unit: "g"),
                    RecipeIngredient(name: "parmesan cheese", quantity: 30, unit: "g"),
                    RecipeIngredient(name: "garlic", quantity: 1, unit: "cloves"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 25, unit: "ml"),
                    RecipeIngredient(name: "cherry tomatoes", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "lemon juice", quantity: 10, unit: "ml"),
                ],
                steps: [
                    "Wash the zucchini, trim the ends and make long ribbons or noodles with a spiralizer or vegetable peeler.",
                    "Place the basil leaves, pine nuts, grated parmesan and peeled garlic in a food processor.",
                    "Pulse briefly, then add the olive oil in a slow stream until the pesto is smooth but retains a little texture.",
                    "Wash and halve the cherry tomatoes, then set aside while you heat a large non-stick pan.",
                    "Add the zucchini noodles to the dry warm pan and toss for 2–3 minutes, just until they soften slightly but are not watery.",
                    "Take the pan off the heat and stir the pesto through the zucchini, loosening with a teaspoon of warm water if needed.",
                    "Fold in the tomatoes, add a little lemon juice and divide into two bowls to serve immediately.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-whole-wheat-pasta-with-tomato-and-spinach", title: "Whole Wheat Pasta with Tomato and Spinach",
                minutes: 30, calories: 420, imageName: "Whole Wheat Pasta with Tomato and Spinach",
                categories: [.vegetarian, .pasta],
                ingredients: [
                    RecipeIngredient(name: "whole-wheat pasta (dry)", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "cherry tomatoes", quantity: 250, unit: "g"),
                    RecipeIngredient(name: "baby spinach", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "garlic", quantity: 2, unit: "cloves"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 20, unit: "ml"),
                    RecipeIngredient(name: "parmesan cheese", quantity: 30, unit: "g"),
                    RecipeIngredient(name: "fresh basil", quantity: 12, unit: "leaves"),
                ],
                steps: [
                    "Fill a large saucepan with water, bring it to a rolling boil and cook the whole-wheat pasta according to the packet until al dente.",
                    "Before draining, reserve a small mug of pasta cooking water, then drain the pasta without rinsing it.",
                    "Wash the tomatoes and spinach; halve the tomatoes and finely chop the peeled garlic.",
                    "Heat the olive oil in a large pan over medium heat and cook the garlic for about 30 seconds until fragrant but not browned.",
                    "Add the tomatoes and cook for 6–8 minutes, pressing a few gently with a spoon to release their juices and form a light sauce.",
                    "Add the spinach in batches, allowing the leaves to wilt, then stir the drained pasta into the sauce.",
                    "Pour in a splash of reserved pasta water if needed, toss until evenly coated, and finish with basil and grated parmesan.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-shrimp-and-avocado-salad", title: "Shrimp and Avocado Salad",
                minutes: 20, calories: 385, imageName: "Shrimp and Avocado Salad",
                categories: [.quick, .highProtein],
                ingredients: [
                    RecipeIngredient(name: "peeled raw shrimp", quantity: 300, unit: "g"),
                    RecipeIngredient(name: "ripe avocado", quantity: 1, unit: "pcs"),
                    RecipeIngredient(name: "mixed salad leaves", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "cucumber", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "cherry tomatoes", quantity: 160, unit: "g"),
                    RecipeIngredient(name: "lime juice", quantity: 25, unit: "ml"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 15, unit: "ml"),
                    RecipeIngredient(name: "smoked paprika", quantity: 2, unit: "g"),
                ],
                steps: [
                    "Rinse and dry the salad leaves and vegetables; halve the tomatoes and cut the cucumber into bite-sized pieces.",
                    "Pat the raw shrimp dry, check for any remaining shell and keep the seafood away from the salad ingredients.",
                    "Mix the smoked paprika with half the olive oil and toss the shrimp lightly in the mixture.",
                    "Heat a non-stick pan over medium-high heat and cook the shrimp for 2–3 minutes on each side until opaque and a thermometer reads 63°C (145°F).",
                    "Remove the shrimp to a clean plate. Cut the avocado in half, discard the stone safely and slice the flesh.",
                    "Whisk together the lime juice and remaining olive oil to make a quick dressing.",
                    "Arrange the salad leaves, cucumber, tomatoes, avocado and cooked shrimp in bowls, drizzle with dressing and serve at once.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-roasted-veggie-wrap", title: "Roasted Veggie Wrap",
                minutes: 35, calories: 410, imageName: "Roasted Veggie Wrap",
                categories: [.vegetarian],
                ingredients: [
                    RecipeIngredient(name: "whole-grain tortillas", quantity: 2, unit: "pcs"),
                    RecipeIngredient(name: "zucchini", quantity: 180, unit: "g"),
                    RecipeIngredient(name: "red bell pepper", quantity: 160, unit: "g"),
                    RecipeIngredient(name: "red onion", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "cooked chickpeas", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "hummus", quantity: 80, unit: "g"),
                    RecipeIngredient(name: "olive oil", quantity: 15, unit: "ml"),
                    RecipeIngredient(name: "baby spinach", quantity: 50, unit: "g"),
                ],
                steps: [
                    "Preheat the oven to 200°C and line a baking tray with baking paper.",
                    "Wash the zucchini and pepper, peel the onion, and cut all three into thin strips of similar thickness.",
                    "Toss the vegetables with olive oil, spread in a single layer and roast for 18–22 minutes until softened and lightly golden.",
                    "Drain the chickpeas, rinse them thoroughly and warm them through in a small pan or alongside the vegetables for the final 5 minutes.",
                    "Lay the whole-grain tortillas on a clean board and spread each with half the hummus, leaving the outer edges clear.",
                    "Add baby spinach, roasted vegetables and chickpeas, then fold the sides inward and roll tightly from the bottom.",
                    "Cut each wrap diagonally with a clean sharp knife and serve while the filling is warm.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-broccoli-and-chickpea-traybake", title: "Broccoli and Chickpea Traybake",
                minutes: 40, calories: 360, imageName: "Broccoli and Chickpea Traybake",
                categories: [.vegetarian],
                ingredients: [
                    RecipeIngredient(name: "broccoli florets", quantity: 350, unit: "g"),
                    RecipeIngredient(name: "cooked chickpeas", quantity: 260, unit: "g"),
                    RecipeIngredient(name: "red onion", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 25, unit: "ml"),
                    RecipeIngredient(name: "smoked paprika", quantity: 4, unit: "g"),
                    RecipeIngredient(name: "ground cumin", quantity: 3, unit: "g"),
                    RecipeIngredient(name: "lemon juice", quantity: 25, unit: "ml"),
                    RecipeIngredient(name: "plain Greek yogurt", quantity: 120, unit: "g"),
                ],
                steps: [
                    "Preheat the oven to 210°C and prepare a large baking tray with parchment paper.",
                    "Wash and dry the broccoli, then cut any large florets into pieces of similar size so they roast evenly.",
                    "Drain and rinse the chickpeas, then pat them dry with kitchen paper to help them become lightly crisp.",
                    "Peel and cut the red onion into wedges, then toss all the vegetables and chickpeas with olive oil, cumin and paprika.",
                    "Spread everything into one layer and roast for 22–27 minutes, turning once, until the broccoli edges are browned and the chickpeas are hot.",
                    "Meanwhile, stir half the lemon juice into the yogurt to make a simple creamy dressing.",
                    "Squeeze the remaining lemon juice over the roasted ingredients, divide into bowls and serve with yogurt sauce on the side.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-vegetable-minestrone", title: "Vegetable Minestrone",
                minutes: 45, calories: 280, imageName: "Vegetable Minestrone",
                categories: [.vegetarian, .pasta],
                ingredients: [
                    RecipeIngredient(name: "zucchini", quantity: 180, unit: "g"),
                    RecipeIngredient(name: "carrot", quantity: 130, unit: "g"),
                    RecipeIngredient(name: "celery stalks", quantity: 2, unit: "pcs"),
                    RecipeIngredient(name: "onion", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "cooked cannellini beans", quantity: 200, unit: "g"),
                    RecipeIngredient(name: "chopped tomatoes", quantity: 240, unit: "g"),
                    RecipeIngredient(name: "low-salt vegetable stock", quantity: 700, unit: "ml"),
                    RecipeIngredient(name: "small whole-wheat pasta", quantity: 80, unit: "g"),
                    RecipeIngredient(name: "olive oil", quantity: 15, unit: "ml"),
                ],
                steps: [
                    "Wash the zucchini, carrot and celery, then chop them into small cubes so they will fit easily onto a spoon.",
                    "Peel and dice the onion, and drain and rinse the cannellini beans under running water.",
                    "Heat the olive oil in a large saucepan and cook the onion, carrot and celery for 6 minutes until just softened.",
                    "Add the zucchini and stir for 2 minutes, then pour in the chopped tomatoes and vegetable stock.",
                    "Bring the soup to a simmer and cook for 12 minutes, allowing the vegetables to become tender.",
                    "Stir in the whole-wheat pasta and cook for the time shown on its packet, stirring occasionally so it does not stick.",
                    "Add the beans during the last 4 minutes to heat them thoroughly without making them mushy.",
                    "Taste the soup, add a splash of hot water if it is too thick and serve warm. Cool leftovers promptly before refrigerating.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-shakshuka", title: "Shakshuka",
                minutes: 35, calories: 320, imageName: "Shakshuka",
                categories: [.vegetarian, .highProtein],
                ingredients: [
                    RecipeIngredient(name: "eggs", quantity: 4, unit: "pcs"),
                    RecipeIngredient(name: "chopped tomatoes", quantity: 400, unit: "g"),
                    RecipeIngredient(name: "red bell pepper", quantity: 160, unit: "g"),
                    RecipeIngredient(name: "onion", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "garlic", quantity: 2, unit: "cloves"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 15, unit: "ml"),
                    RecipeIngredient(name: "ground cumin", quantity: 3, unit: "g"),
                    RecipeIngredient(name: "smoked paprika", quantity: 3, unit: "g"),
                    RecipeIngredient(name: "fresh parsley", quantity: 12, unit: "g"),
                ],
                steps: [
                    "Peel and finely dice the onion and garlic, then wash the red pepper, remove the seeds and cut it into small cubes.",
                    "Heat the olive oil in a deep frying pan and cook the onion and pepper for 7–8 minutes until softened.",
                    "Stir in the garlic, cumin and smoked paprika and cook for 30 seconds, stirring constantly to prevent burning.",
                    "Add the chopped tomatoes and simmer uncovered for 10–12 minutes until the sauce has thickened slightly.",
                    "Use a spoon to make four small wells in the sauce and crack one egg into each well without breaking the yolk.",
                    "Cover the pan and cook gently until the eggs are fully set, or until cooked to your preferred doneness according to local safety guidance.",
                    "Wash and chop the parsley, sprinkle over the pan and divide into two servings with the tomato sauce.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-chicken-quinoa-bowl", title: "Chicken Quinoa Bowl",
                minutes: 35, calories: 515, imageName: "Chicken Quinoa Bowl",
                categories: [.highProtein],
                ingredients: [
                    RecipeIngredient(name: "boneless chicken breast", quantity: 300, unit: "g"),
                    RecipeIngredient(name: "dry quinoa", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "baby spinach", quantity: 80, unit: "g"),
                    RecipeIngredient(name: "cucumber", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "cherry tomatoes", quantity: 140, unit: "g"),
                    RecipeIngredient(name: "plain Greek yogurt", quantity: 80, unit: "g"),
                    RecipeIngredient(name: "lemon juice", quantity: 20, unit: "ml"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 15, unit: "ml"),
                ],
                steps: [
                    "Rinse the quinoa in a sieve and cook with twice its volume of water until tender, usually around 12–15 minutes.",
                    "Remove the quinoa from the heat, let it rest covered for 5 minutes and then fluff it with a fork.",
                    "Wash the spinach, cucumber and tomatoes, dice the cucumber and halve the tomatoes before setting them aside.",
                    "Pat the chicken dry and brush lightly with olive oil. Cook in a hot non-stick pan, turning occasionally until browned.",
                    "Check the center of the chicken reaches 74°C (165°F), then rest on a clean board for 3 minutes before slicing.",
                    "Mix the Greek yogurt and lemon juice in a small bowl to make a tangy sauce, adding water to thin if needed.",
                    "Divide the quinoa between two bowls, arrange the chicken and fresh vegetables on top, then spoon over the yogurt dressing.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-mediterranean-baked-cod", title: "Mediterranean Baked Cod",
                minutes: 30, calories: 365, imageName: "Mediterranean Baked Cod",
                categories: [.highProtein],
                ingredients: [
                    RecipeIngredient(name: "cod fillets", quantity: 300, unit: "g"),
                    RecipeIngredient(name: "cherry tomatoes", quantity: 220, unit: "g"),
                    RecipeIngredient(name: "zucchini", quantity: 180, unit: "g"),
                    RecipeIngredient(name: "Kalamata olives", quantity: 50, unit: "g"),
                    RecipeIngredient(name: "lemon", quantity: 1, unit: "pcs"),
                    RecipeIngredient(name: "olive oil", quantity: 20, unit: "ml"),
                    RecipeIngredient(name: "garlic", quantity: 2, unit: "cloves"),
                    RecipeIngredient(name: "dried oregano", quantity: 2, unit: "g"),
                ],
                steps: [
                    "Preheat the oven to 200°C and lightly oil a baking dish large enough to hold the cod fillets without overlapping.",
                    "Wash the zucchini and tomatoes, slice the zucchini into thin half-moons and halve the tomatoes.",
                    "Scatter the vegetables and olives in the dish, drizzle with half the olive oil and roast for 10 minutes.",
                    "Pat the cod fillets dry with kitchen paper, check for bones and place them gently over the partly cooked vegetables.",
                    "Mix the remaining oil with chopped garlic, oregano and a squeeze of lemon, then spoon over the fish.",
                    "Return to the oven for 12–15 minutes, depending on thickness, until the fish is opaque and reaches 63°C (145°F) in the center.",
                    "Serve the cod with the vegetables and lemon wedges, discarding any bones found during cooking.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-baked-sweet-potato-with-chickpeas", title: "Baked Sweet Potato with Chickpeas",
                minutes: 45, calories: 475, imageName: "Baked Sweet Potato with Chickpeas",
                categories: [.vegetarian],
                ingredients: [
                    RecipeIngredient(name: "medium sweet potatoes", quantity: 2, unit: "pcs"),
                    RecipeIngredient(name: "cooked chickpeas", quantity: 240, unit: "g"),
                    RecipeIngredient(name: "baby spinach", quantity: 80, unit: "g"),
                    RecipeIngredient(name: "plain Greek yogurt", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "lemon juice", quantity: 20, unit: "ml"),
                    RecipeIngredient(name: "olive oil", quantity: 10, unit: "ml"),
                    RecipeIngredient(name: "ground cumin", quantity: 3, unit: "g"),
                    RecipeIngredient(name: "fresh parsley", quantity: 10, unit: "g"),
                ],
                steps: [
                    "Preheat the oven to 200°C, scrub the sweet potatoes clean and prick each one several times with a fork.",
                    "Place the potatoes on a lined baking tray and bake for 35–45 minutes until a knife slides easily into the center.",
                    "While they cook, drain and rinse the chickpeas and gently heat them in a small pan with olive oil and ground cumin.",
                    "Wash and dry the baby spinach and chop the parsley into small pieces.",
                    "Stir the Greek yogurt with the lemon juice in a bowl to make a quick tangy topping.",
                    "Split each cooked sweet potato lengthwise without cutting all the way through, then lightly mash the flesh with a fork.",
                    "Stuff the potatoes with spinach and chickpeas, add the yogurt dressing and finish with fresh parsley before serving.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-vegetable-frittata", title: "Vegetable Frittata",
                minutes: 35, calories: 350, imageName: "Vegetable Frittata",
                categories: [.highProtein, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "eggs", quantity: 5, unit: "pcs"),
                    RecipeIngredient(name: "baby spinach", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "zucchini", quantity: 160, unit: "g"),
                    RecipeIngredient(name: "cherry tomatoes", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "feta cheese", quantity: 60, unit: "g"),
                    RecipeIngredient(name: "milk", quantity: 40, unit: "ml"),
                    RecipeIngredient(name: "olive oil", quantity: 10, unit: "ml"),
                ],
                steps: [
                    "Preheat the oven to 190°C and choose an oven-safe non-stick frying pan or small baking dish.",
                    "Wash the zucchini, spinach and cherry tomatoes, then dice the zucchini and halve the tomatoes.",
                    "Heat olive oil in the oven-safe pan, add zucchini and cook for 5 minutes before stirring in the spinach.",
                    "Whisk the eggs and milk together in a bowl until uniform, then crumble the feta into the mixture.",
                    "Arrange the tomatoes over the softened vegetables, pour in the egg mixture and cook on the stove for 2 minutes.",
                    "Transfer the pan carefully to the oven and bake for 12–16 minutes until the center is fully set and a food thermometer in the middle reads at least 71°C (160°F).",
                    "Let the frittata rest for 3 minutes, slide it onto a board and cut into portions for two people.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-baked-oatmeal-with-berries", title: "Baked Oatmeal with Berries",
                minutes: 40, calories: 345, imageName: "Baked Oatmeal with Berries",
                categories: [.vegetarian],
                ingredients: [
                    RecipeIngredient(name: "rolled oats", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "milk", quantity: 240, unit: "ml"),
                    RecipeIngredient(name: "eggs", quantity: 2, unit: "pcs"),
                    RecipeIngredient(name: "blueberries", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "raspberries", quantity: 100, unit: "g"),
                    RecipeIngredient(name: "ripe banana", quantity: 1, unit: "pcs"),
                    RecipeIngredient(name: "baking powder", quantity: 5, unit: "g"),
                    RecipeIngredient(name: "ground cinnamon", quantity: 2, unit: "g"),
                ],
                steps: [
                    "Preheat the oven to 180°C and lightly grease a small baking dish or line it with parchment paper.",
                    "Mash the banana in a mixing bowl, crack in the eggs and whisk until mostly smooth.",
                    "Pour in the milk and stir, then add the rolled oats, baking powder and cinnamon and mix thoroughly.",
                    "Rinse the blueberries and raspberries gently and fold most of them into the oat mixture without crushing them.",
                    "Pour the mixture into the prepared dish and spread it level, then scatter the remaining berries over the top.",
                    "Bake for 28–32 minutes, until the center is fully set and the surface is lightly golden.",
                    "Rest the baked oatmeal for 5 minutes before cutting into two servings; store leftovers refrigerated.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-chicken-and-vegetable-soup", title: "Chicken and Vegetable Soup",
                minutes: 45, calories: 315, imageName: "Chicken and Vegetable Soup",
                categories: [.highProtein],
                ingredients: [
                    RecipeIngredient(name: "boneless chicken breast", quantity: 300, unit: "g"),
                    RecipeIngredient(name: "carrots", quantity: 150, unit: "g"),
                    RecipeIngredient(name: "celery stalks", quantity: 2, unit: "pcs"),
                    RecipeIngredient(name: "onion", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "baby spinach", quantity: 80, unit: "g"),
                    RecipeIngredient(name: "low-salt chicken stock", quantity: 800, unit: "ml"),
                    RecipeIngredient(name: "olive oil", quantity: 10, unit: "ml"),
                    RecipeIngredient(name: "whole-wheat noodles", quantity: 100, unit: "g"),
                ],
                steps: [
                    "Wash the carrots and celery and cut into small pieces; peel and finely dice the onion.",
                    "Warm the olive oil in a large saucepan and cook the onion, carrot and celery for about 6 minutes to soften them.",
                    "Pour in the chicken stock and bring the mixture to a gentle boil, then reduce the heat to a steady simmer.",
                    "Add the raw chicken breasts and poach gently until the thickest part reaches 74°C (165°F), approximately 15–20 minutes.",
                    "Lift the chicken out with clean tongs, let it cool slightly and shred it using two clean forks.",
                    "Add the whole-wheat noodles to the simmering soup and cook according to the packet directions until tender.",
                    "Return the shredded chicken to the pot, add the spinach and simmer 2 minutes until hot throughout and wilted.",
                    "Divide between bowls and serve hot, refrigerating leftovers promptly after they have cooled safely.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-black-bean-and-corn-salad", title: "Black Bean and Corn Salad",
                minutes: 15, calories: 380, imageName: "Black Bean and Corn Salad",
                categories: [.quick, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "cooked black beans", quantity: 250, unit: "g"),
                    RecipeIngredient(name: "sweetcorn kernels", quantity: 200, unit: "g"),
                    RecipeIngredient(name: "cherry tomatoes", quantity: 160, unit: "g"),
                    RecipeIngredient(name: "red bell pepper", quantity: 120, unit: "g"),
                    RecipeIngredient(name: "red onion", quantity: 60, unit: "g"),
                    RecipeIngredient(name: "lime juice", quantity: 25, unit: "ml"),
                    RecipeIngredient(name: "extra-virgin olive oil", quantity: 15, unit: "ml"),
                    RecipeIngredient(name: "fresh coriander", quantity: 15, unit: "g"),
                ],
                steps: [
                    "Drain and rinse the black beans and sweetcorn thoroughly, then leave them in a sieve to remove excess water.",
                    "Wash the tomatoes, bell pepper and fresh coriander, then pat the vegetables dry.",
                    "Halve the tomatoes, finely dice the pepper and peel and mince the red onion into small pieces.",
                    "Place beans, sweetcorn, tomatoes, pepper and onion in a large bowl, then add the chopped coriander.",
                    "Whisk the lime juice and olive oil in a small bowl until the dressing is emulsified.",
                    "Pour the dressing over the salad, mix gently and taste before adding any additional seasoning.",
                    "Let stand for 5 minutes for the flavors to blend, then serve chilled or at room temperature.",
                ], baseServings: 2
            ),
            StoredRecipe(
                id: "catalog-berry-protein-smoothie", title: "Berry Protein Smoothie",
                minutes: 10, calories: 285, imageName: "Berry Protein Smoothie",
                categories: [.quick, .highProtein, .vegetarian],
                ingredients: [
                    RecipeIngredient(name: "plain Greek yogurt", quantity: 300, unit: "g"),
                    RecipeIngredient(name: "mixed frozen berries", quantity: 200, unit: "g"),
                    RecipeIngredient(name: "ripe banana", quantity: 1, unit: "pcs"),
                    RecipeIngredient(name: "milk or unsweetened plant milk", quantity: 200, unit: "ml"),
                    RecipeIngredient(name: "rolled oats", quantity: 30, unit: "g"),
                    RecipeIngredient(name: "chia seeds", quantity: 15, unit: "g"),
                ],
                steps: [
                    "Check that the frozen berries are suitable for use without cooking according to the package directions.",
                    "Peel the banana and cut it into large chunks to help the blender process it evenly.",
                    "Pour the milk into the blender, then add the Greek yogurt, oats, chia seeds, banana and berries.",
                    "Blend on low speed first, then increase gradually until the drink is completely smooth and creamy.",
                    "If the mixture seems too thick, add a splash of milk and pulse again until it reaches a pourable texture.",
                    "Divide between two glasses and drink promptly while cold; refrigerate any leftover smoothie immediately.",
                ], baseServings: 2
            ),
        ]
    }
}
