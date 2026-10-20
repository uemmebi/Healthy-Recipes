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
            if let photo = RecipeImageStore.image(named: recipe.imageName) {
                Image(uiImage: photo).resizable().scaledToFill()
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


struct VerticalRecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            NavigationLink(value: recipe) {
                RecipeArtwork(recipe: recipe)
                    .frame(width: 108, height: 104)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            NavigationLink(value: recipe) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(recipe.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    HStack(spacing: 7) {
                        Image(systemName: "clock")
                        Text("\(recipe.minutes) min")
                        if let calories = recipe.calories {
                            Text("·")
                            Text("~\(calories) kcal")
                        }
                    }
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            FavoriteButton(recipe: recipe)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 4)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Images bundled with the app use their asset name (matching the recipe title).
/// User-selected images live as JPEG files in Application Support/RecipePhotos.
/// Both sources are represented by a single String: imageName.
enum RecipeImageStore {
    static let missingImageName = "NoImage"
    private static let prefix = "user-photo-"

    private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                             in: .userDomainMask)[0]
        return base.appendingPathComponent("RecipePhotos", isDirectory: true)
    }

    private static func localURL(for imageName: String) -> URL? {
        guard imageName.hasPrefix(prefix), imageName.hasSuffix(".jpg"),
              !imageName.contains("/"), !imageName.contains("\\") else { return nil }
        return folder.appendingPathComponent(imageName, isDirectory: false)
    }

    static func image(named imageName: String) -> UIImage? {
        if let url = localURL(for: imageName) {
            return UIImage(contentsOfFile: url.path)
        }
        return UIImage(named: imageName)
    }

    /// Saves a selected photo separately from SwiftData; only the filename is persisted.
    static func save(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.78) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return try saveJPEGData(data)
    }

    /// Used only when migrating old records that contain inline image bytes.
    static func saveJPEGData(_ data: Data) throws -> String {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = prefix + UUID().uuidString + ".jpg"
        try data.write(to: folder.appendingPathComponent(name), options: .atomic)
        return name
    }

    static func deleteIfLocal(named imageName: String) {
        guard let url = localURL(for: imageName) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
