//
//  RecipeEditorView.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

private struct IngredientDraft: Identifiable {
    var id: String = UUID().uuidString
    var name: String = ""
    var amount: String = ""
    var unit: String = "g"

    init() {}
    init(_ ingredient: RecipeIngredient) {
        id = ingredient.id
        name = ingredient.name
        amount = QuantityText.format(ingredient.quantity)
        unit = ingredient.unit
    }

    var parsedAmount: Double? {
        Double(amount.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "."))
    }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (parsedAmount ?? 0) > 0
    }
    var stored: RecipeIngredient {
        RecipeIngredient(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                         quantity: parsedAmount ?? 1, unit: unit)
    }
}

private struct StepDraft: Identifiable {
    var id = UUID()
    var text: String = ""
    init(_ text: String = "") { self.text = text }
}

struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let existing: StoredRecipe?
    @State private var title: String
    @State private var minutesText: String
    @State private var caloriesText: String
    @State private var baseServings: Int
    @State private var categories: Set<RecipeCategory>
    @State private var ingredients: [IngredientDraft]
    @State private var steps: [StepDraft]
    @State private var imageName: String
    @State private var selectedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var saveError = false

    init(existing: StoredRecipe? = nil) {
        self.existing = existing
        _title = State(initialValue: existing?.title ?? "")
        _minutesText = State(initialValue: existing.map { String($0.minutes) } ?? "")
        _caloriesText = State(initialValue: existing?.calories.map { String($0) } ?? "")
        _baseServings = State(initialValue: existing?.baseServings ?? 1)
        _categories = State(initialValue: Set(existing?.categoryNames.compactMap(RecipeCategory.init(rawValue:)) ?? []))
        _ingredients = State(initialValue: existing?.ingredients.map(IngredientDraft.init) ?? [IngredientDraft()])
        _steps = State(initialValue: existing?.steps.map(StepDraft.init) ?? [StepDraft()])
        _imageName = State(initialValue: existing?.imageName ?? RecipeImageStore.missingImageName)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Int(minutesText) ?? 0) > 0 &&
        (caloriesText.isEmpty || (Int(caloriesText) ?? -1) >= 0) &&
        !ingredients.isEmpty && ingredients.allSatisfy(\.isValid) &&
        !steps.isEmpty && steps.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        Form {
            photoSection
            recipeDetailsSection
            categoriesSection
            ingredientsSection
            preparationSection
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle(existing == nil ? "New Recipe" : "Edit Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                let maxSide: CGFloat = 1600
                let scale = min(1, maxSide / max(image.size.width, image.size.height))
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: size)
                let resized = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                selectedImage = resized
            }
        }
        .alert("Couldn't save recipe", isPresented: $saveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again. Your changes are still in the form.")
        }
    }


    private var photoSection: some View {
        Section("Photo (optional)") {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack(spacing: 15) {
                    if let photo = selectedImage ?? RecipeImageStore.image(named: imageName) {
                        Image(uiImage: photo).resizable().scaledToFill()
                            .frame(width: 78, height: 78).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 27, weight: .light))
                            .foregroundStyle(AppTheme.primaryGreen)
                            .frame(width: 78, height: 78)
                            .background(AppTheme.chipBackground, in: RoundedRectangle(cornerRadius: 12))
                    }
                    Text(selectedImage == nil && imageName == RecipeImageStore.missingImageName ? "Choose a photo" : "Change photo")
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
        }
    }

    private var recipeDetailsSection: some View {
        Section("Recipe details") {
            TextField("Recipe name", text: $title)
            HStack {
                Text("Preparation time")
                Spacer()
                TextField("Minutes", text: $minutesText)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .frame(width: 75)
                Text("min").foregroundStyle(.secondary)
            }
            HStack {
                Text("Calories for 1 serving (optional)")
                Spacer()
                TextField("kcal", text: $caloriesText)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .frame(width: 70)
            }
            Stepper("Base servings: \(baseServings)", value: $baseServings, in: 1...24)
        }
    }

    private var categoriesSection: some View {
        Section("Categories") {
            ForEach(RecipeCategory.allCases.filter { $0 != .all }) { category in
                Toggle(category.rawValue, isOn: Binding(
                    get: { categories.contains(category) },
                    set: { value in
                        if value { categories.insert(category) }
                        else { categories.remove(category) }
                    }
                ))
                .tint(AppTheme.primaryGreen)
            }
        }
    }

    private var ingredientsSection: some View {
        Section {
            ForEach($ingredients) { $ingredient in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Amount", text: $ingredient.amount)
                            .keyboardType(.decimalPad)
                            .frame(width: 74)
                            .textFieldStyle(.roundedBorder)
                        Picker("Unit", selection: $ingredient.unit) {
                            ForEach(["g", "kg", "ml", "l", "pcs", "tbsp", "tsp", "cups", "cloves", "leaves"], id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 110)
                        Spacer()
                        Button(role: .destructive) {
                            ingredients.removeAll { $0.id == ingredient.id }
                        } label: { Image(systemName: "minus.circle") }
                            .disabled(ingredients.count <= 1)
                    }
                    TextField("Ingredient name (e.g. tomatoes)", text: $ingredient.name)
                }
                .padding(.vertical, 3)
            }
            Button { ingredients.append(IngredientDraft()) } label: {
                Label("Add ingredient", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Ingredients")
        } footer: {
            Text("Enter amounts for the base servings. The recipe scales them automatically.")
        }
    }

    private var preparationSection: some View {
        Section {
            ForEach($steps) { $step in
                HStack(alignment: .top, spacing: 9) {
                    Text("\(steps.firstIndex(where: { $0.id == step.id }).map { $0 + 1 } ?? 1).")
                        .fontWeight(.semibold).foregroundStyle(AppTheme.primaryGreen)
                    TextField("Describe one action clearly", text: $step.text, axis: .vertical)
                        .lineLimit(2...5)
                    Button(role: .destructive) {
                        steps.removeAll { $0.id == step.id }
                    } label: { Image(systemName: "minus.circle") }
                        .disabled(steps.count <= 1)
                }
                .padding(.vertical, 5)
            }
            Button { steps.append(StepDraft()) } label: {
                Label("Add preparation step", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Preparation")
        } footer: {
            Text("Write a separate step for every action, including cooking times and temperatures.")
        }
    }

    private func save() {
        guard isValid, let minutes = Int(minutesText) else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoriesList = categories.map { $0 }.sorted { $0.rawValue < $1.rawValue }
        let newIngredients = ingredients.map(\.stored)
        let newSteps = steps.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }

        // Keep the previous file until the database update succeeds.
        let previousName = existing?.imageName ?? RecipeImageStore.missingImageName
        let chosenName: String
        do {
            if let selectedImage {
                chosenName = try RecipeImageStore.save(selectedImage)
            } else {
                chosenName = imageName
            }
        } catch {
            saveError = true
            return
        }

        if let existing {
            existing.title = trimmedTitle
            existing.imageName = chosenName
            existing.minutes = minutes
            existing.calories = Int(caloriesText)
            existing.baseServings = baseServings
            existing.categoryNames = categoriesList.map(\.rawValue)
            existing.ingredients = newIngredients
            existing.steps = newSteps
            existing.photoData = nil // Old SwiftData image bytes are no longer needed.
        } else {
            let newRecipe = StoredRecipe(
                id: "user-" + UUID().uuidString,
                title: trimmedTitle, minutes: minutes, calories: Int(caloriesText),
                imageName: chosenName, categories: categoriesList,
                ingredients: newIngredients, steps: newSteps,
                baseServings: baseServings, isUserCreated: true
            )
            context.insert(newRecipe)
        }
        do {
            try context.save()
            if chosenName != previousName { RecipeImageStore.deleteIfLocal(named: previousName) }
            dismiss()
        } catch {
            if chosenName != previousName { RecipeImageStore.deleteIfLocal(named: chosenName) }
            saveError = true
        }
    }
}
