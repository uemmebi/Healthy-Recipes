//
//  UserProfileView.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 20/10/2026.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Editable profile and recipe collections.
struct UserProfileView: View {
    @AppStorage("healthyRecipes.profile.displayName") private var displayName = ""
    @AppStorage("healthyRecipes.profile.imageName") private var imageName = "NoImage"
    @Query(sort: \StoredRecipe.createdAt, order: .reverse) private var storedRecipes: [StoredRecipe]
    @State private var isEditing = false

    private var createdRecipes: [Recipe] {
        storedRecipes.filter(\.isUserCreated).map(\.asRecipe)
    }

    private var favoriteRecipes: [Recipe] {
        storedRecipes.filter(\.isFavorite).map(\.asRecipe)
    }

    private var profileTitle: String {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Your Kitchen" : name
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("You")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.top, 18)

                profileCard

                VStack(alignment: .leading, spacing: 13) {
                    Text("Your collections")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    HStack(spacing: 12) {
                        NavigationLink(value: RecipeCollection.createdByYou) {
                            RecipeStatCard(
                                title: "Created by You",
                                count: createdRecipes.count,
                                symbol: "book.closed",
                                preview: createdRecipes.first
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(value: RecipeCollection.favorites) {
                            RecipeStatCard(
                                title: "Favorites",
                                count: favoriteRecipes.count,
                                symbol: "heart",
                                preview: favoriteRecipes.first
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

            }
            .padding(.horizontal, 16)
            .padding(.bottom, 115) // Space for the existing floating tab bar.
        }
        .background(AppTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                LocalProfileEditor(name: displayName, imageName: imageName) { name, newPhoto, removePhoto in
                    if let newPhoto {
                        do {
                            let storedName = try RecipeImageStore.save(newPhoto)
                            let oldName = imageName
                            imageName = storedName
                            RecipeImageStore.deleteIfLocal(named: oldName)
                        } catch {
                            return false
                        }
                    } else if removePhoto {
                        let oldName = imageName
                        imageName = "NoImage"
                        RecipeImageStore.deleteIfLocal(named: oldName)
                    }
                    displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    return true
                }
            }
            .tint(AppTheme.primaryGreen)
        }
    }

    private var profileCard: some View {
        HStack(spacing: 16) {
            ProfilePhoto(imageName: imageName, size: 84)

            VStack(alignment: .leading, spacing: 5) {
                Text(profileTitle)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(2)
                    .foregroundStyle(AppTheme.primaryText)

                Text(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                     ? "Add a name or photo"
                     : "Your personal recipe collection")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button { isEditing = true } label: {
                    Label("Edit profile", systemImage: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryGreen)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(AppTheme.chipBackground, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 14, x: 0, y: 5)
    }
}

private struct RecipeStatCard: View {
    let title: String
    let count: Int
    let symbol: String
    let preview: Recipe?

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(AppTheme.primaryGreen)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.chipBackground, in: Circle())

                Spacer(minLength: 4)

                if let preview {
                    RecipeArtwork(recipe: preview)
                        .frame(width: 47, height: 47)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Spacer(minLength: 0)

            Text(count, format: .number)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .foregroundStyle(AppTheme.primaryText)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) \(title). Open collection")
    }
}

private struct ProfilePhoto: View {
    let imageName: String
    let size: CGFloat

    var body: some View {
        Group {
            if let image = RecipeImageStore.image(named: imageName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    AppTheme.chipBackground
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.62, height: size * 0.62)
                        .foregroundStyle(AppTheme.primaryGreen.opacity(0.75))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("Profile photo")
    }
}

private struct LocalProfileEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var removePhoto = false
    @State private var photoSaveFailed = false

    let imageName: String
    let onSave: (String, UIImage?, Bool) -> Bool

    init(name: String, imageName: String,
         onSave: @escaping (String, UIImage?, Bool) -> Bool) {
        _name = State(initialValue: name)
        self.imageName = imageName
        self.onSave = onSave
    }

    private var currentImage: UIImage? {
        if let pickedImage { return pickedImage }
        return removePhoto ? nil : RecipeImageStore.image(named: imageName)
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Group {
                        if let photo = currentImage {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                AppTheme.chipBackground
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 55))
                                    .foregroundStyle(AppTheme.primaryGreen.opacity(0.75))
                            }
                        }
                    }
                    .frame(width: 112, height: 112)
                    .clipShape(Circle())

                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label("Choose photo", systemImage: "photo")
                            .font(.subheadline.weight(.semibold))
                    }

                    if currentImage != nil {
                        Button("Remove photo", role: .destructive) {
                            pickedItem = nil
                            pickedImage = nil
                            removePhoto = true
                        }
                        .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("Name") {
                TextField("Your name", text: $name)
                    .textContentType(.nickname)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            }

        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if onSave(name, pickedImage, removePhoto) {
                        dismiss()
                    } else {
                        photoSaveFailed = true
                    }
                }
                .fontWeight(.semibold)
                            }
        }
        .alert("Couldn't save photo", isPresented: $photoSaveFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try choosing a different photo.")
        }
        .onChange(of: pickedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                await MainActor.run {
                    pickedImage = image
                    removePhoto = false
                }
            }
        }
    }
}
