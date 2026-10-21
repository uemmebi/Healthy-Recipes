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
    @State private var showingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                if showingSplash {
                    BrandSplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .tint(AppTheme.primaryGreen)
            .preferredColorScheme(.light)
            .task {
                try? await Task.sleep(nanoseconds: 850_000_000)
                withAnimation(.easeOut(duration: 0.18)) {
                    showingSplash = false
                }
            }
        }
        .modelContainer(for: [StoredRecipe.self, GroceryItem.self, MealPlanEntry.self])
    }
}

private struct BrandSplashView: View {
    var body: some View {
        ZStack {
            AppTheme.background

            Image("BrandMark")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .accessibilityLabel("Healthy Recipes")
    }
}
