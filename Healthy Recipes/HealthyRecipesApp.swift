//
//  HealthyRecipesApp.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import SwiftUI
import SwiftData

@main
struct HealthyRecipesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(AppTheme.primaryGreen)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [StoredRecipe.self, GroceryItem.self, UserRecipe.self])
    }
}
