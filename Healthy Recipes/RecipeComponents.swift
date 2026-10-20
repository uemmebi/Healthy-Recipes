//
//  RecipeComponents.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import SwiftUI
import SwiftData
import UIKit

struct RecipeArtwork: View {
    let recipe: Recipe

    var body: some View {
        Group {
            if let bytes = recipe.imageData, let photo = UIImage(data: bytes) {
                Image(uiImage: photo).resizable().scaledToFill()
            } else if !recipe.imageName.isEmpty {
                Image(recipe.imageName).resizable().scaledToFill()
            } else {
                ZStack {
                    AppTheme.chipBackground
                    Image(systemName: "leaf")
                        .font(.system(size: 46, weight: .ultraLight))
                        .foregroundStyle(AppTheme.primaryGreen)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct FavoriteButton: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var savedRecipes: [StoredRecipe]
    let recipe: Recipe
    var prominent = false

    private var stored: StoredRecipe? { savedRecipes.first { $0.id == recipe.id } }
    private var isFavorite: Bool { stored?.isFavorite ?? recipe.isFavorite }

    var body: some View {
        Button {
            guard let stored else { return }
            stored.isFavorite.toggle()
            try? modelContext.save()
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: prominent ? 23 : 18, weight: .medium))
                .foregroundStyle(isFavorite ? AppTheme.heart : AppTheme.primaryText)
                .frame(width: prominent ? 43 : 35, height: prominent ? 43 : 35)
                .background(Circle().fill(Color.white.opacity(0.97)))
                .contentShape(Circle())
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}

struct FeaturedRecipeCard: View {
    let recipe: Recipe

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width * (334.0 / 588.0)

            ZStack(alignment: .topTrailing) {
                NavigationLink(value: recipe) {
                    RecipeArtwork(recipe: recipe)
                        .frame(width: width, height: height)
                        .clipped()
                        .overlay {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.35),
                                    .init(color: .black.opacity(0.10), location: 0.60),
                                    .init(color: .black.opacity(0.70), location: 1)
                                ], startPoint: .top, endPoint: .bottom
                            )
                        }
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(recipe.title)
                                    .font(.system(size: 22, weight: .bold))
                                    .tracking(-0.35).lineLimit(1).minimumScaleFactor(0.8)
                                HStack(alignment: .center, spacing: 18) {
                                    Label("\(recipe.minutes) min", systemImage: "clock")
                                    if recipe.calories != nil {
                                        Label(recipe.caloriesText, systemImage: "flame")
                                    }
                                }
                                .font(.system(size: 15, weight: .medium))
                                .lineLimit(1)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 16)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                FavoriteButton(recipe: recipe, prominent: true)
                    .padding(.top, 11).padding(.trailing, 12)
            }
        }
        .aspectRatio(588.0 / 334.0, contentMode: .fit)
    }
}

struct CompactRecipeCard: View {
    let recipe: Recipe
    var width: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                NavigationLink(value: recipe) {
                    RecipeArtwork(recipe: recipe)
                        .frame(width: width, height: width).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                FavoriteButton(recipe: recipe)
                    .padding(.top, 6).padding(.trailing, 8)
            }
            .frame(width: width, height: width)

            NavigationLink(value: recipe) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(recipe.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1).truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                            .frame(width: 15, height: 16)
                        Text("\(recipe.minutes) min")
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(height: 17)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: width, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(width: width, alignment: .leading)
    }
}
