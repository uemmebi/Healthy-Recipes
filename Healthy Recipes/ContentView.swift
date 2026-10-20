//
//  ContentView.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import SwiftUI
import SwiftData

private enum MainTab: String, CaseIterable, Identifiable {
    case recipes = "Recipes"
    case mealPlan = "Meal Plan"
    case groceries = "Groceries"
    case you = "You"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .recipes: "fork.knife"
        case .mealPlan: "calendar"
        case .groceries: "cart"
        case .you: "person"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentTab: MainTab = .recipes

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()
            Group {
                switch currentTab {
                case .recipes:
                    NavigationStack {
                        RecipesHomeView()
                            .navigationDestination(for: Recipe.self) { recipe in
                                RecipeDetailView(recipe: recipe)
                            }
                            .navigationDestination(for: RecipeCollection.self) { collection in
                                RecipeCollectionView(collection: collection)
                            }
                    }
                case .mealPlan:
                    PlaceholderTabView(title: "Meal Plan", symbol: "calendar", description: "Your weekly meal plan will appear here.")
                case .groceries:
                    NavigationStack { GroceryListView() }
                case .you:
                    PlaceholderTabView(title: "You", symbol: "person.crop.circle", description: "Your profile and preferences will appear here.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(currentTab: $currentTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .task {
            await MainActor.run { RecipeSeeds.installIfNeeded(in: modelContext) }
        }
    }
}

private struct FloatingTabBar: View {
    @Binding var currentTab: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { currentTab = tab }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 24, weight: .medium))
                            .frame(height: 28)
                        Text(tab.rawValue)
                            .font(.system(size: 10.5, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(currentTab == tab ? AppTheme.primaryGreen : Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background {
                        if currentTab == tab {
                            Capsule().fill(AppTheme.primaryGreen.opacity(0.10)).padding(3)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(currentTab == tab ? [.isSelected] : [])
            }
        }
        .padding(3)
        .frame(height: 56)
        .background {
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                HStack(spacing: 0) {
                    Circle().fill(AppTheme.softGreen.opacity(0.52))
                    Circle().fill(Color.orange.opacity(0.17))
                    Circle().fill(AppTheme.softGreen.opacity(0.30))
                    Circle().fill(Color.red.opacity(0.19))
                }
                .blur(radius: 15)
            }
            .clipShape(Capsule())
        }
        .overlay { Capsule().strokeBorder(.white.opacity(0.85), lineWidth: 1) }
        .shadow(color: .black.opacity(0.15), radius: 13, x: 0, y: 5)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [StoredRecipe.self, GroceryItem.self, UserRecipe.self], inMemory: true)
}
