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
        guard let parsedAmount else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            parsedAmount.isFinite && parsedAmount > 0 && !unit.isEmpty
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
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String
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
        // Stored nutrition is per single serving; the editor shows totals for baseServings.
        let servings = min(24, max(1, existing?.baseServings ?? 1))
        _caloriesText = State(initialValue: existing?.calories.map { String($0 * servings) } ?? "")
        _proteinText = State(initialValue: existing?.proteinGrams.map { QuantityText.format($0 * Double(servings)) } ?? "")
        _carbsText = State(initialValue: existing?.carbsGrams.map { QuantityText.format($0 * Double(servings)) } ?? "")
        _fatText = State(initialValue: existing?.fatGrams.map { QuantityText.format($0 * Double(servings)) } ?? "")
        _baseServings = State(initialValue: min(24, max(1, existing?.baseServings ?? 1)))
        _categories = State(initialValue: Set(existing?.categoryNames.compactMap(RecipeCategory.init(rawValue:)) ?? []))
        _ingredients = State(initialValue: existing?.ingredients.map(IngredientDraft.init) ?? [IngredientDraft()])
        _steps = State(initialValue: existing?.steps.map(StepDraft.init) ?? [StepDraft()])
        _imageName = State(initialValue: existing?.imageName ?? RecipeImageStore.missingImageName)
    }

    private func numericValue(_ text: String) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let number = Double(value), number.isFinite else { return nil }
        return number
    }

    private func optionalNonnegative(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || (numericValue(trimmed).map { $0 >= 0 } ?? false)
    }

    private func nutritionPerServing(_ text: String) -> Double? {
        guard let total = numericValue(text) else { return nil }
        return total / Double(baseServings)
    }

    private var caloriesPerServing: Int? {
        let trimmed = caloriesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let total = Int(trimmed), total >= 0 else { return nil }
        return Int((Double(total) / Double(baseServings)).rounded())
    }

    private var isValid: Bool {
        let trimmedMinutes = minutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCalories = caloriesText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (Int(trimmedMinutes).map { $0 > 0 } ?? false) &&
            (1...24).contains(baseServings) &&
            (trimmedCalories.isEmpty || (Int(trimmedCalories).map { $0 >= 0 } ?? false)) &&
            optionalNonnegative(proteinText) &&
            optionalNonnegative(carbsText) &&
            optionalNonnegative(fatText) &&
            !ingredients.isEmpty && ingredients.allSatisfy(\.isValid)
        // Photo, vegetarian status, calories, macros and preparation steps are optional.
    }

    var body: some View {
        Form {
            photoSection
            recipeDetailsSection
            nutritionSection
            vegetarianToggle
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
                Text("Calories (optional)")
                Spacer()
                TextField("kcal", text: $caloriesText)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .frame(width: 70)
            }
            HStack(spacing: 12) {
                Text("Servings")
                Spacer()
                Button {
                    baseServings = max(1, baseServings - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(baseServings == 1)
                .accessibilityLabel("Decrease servings")

                Text("\(baseServings)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 24)
                    .accessibilityLabel("\(baseServings) servings")

                Button {
                    baseServings = min(24, baseServings + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(baseServings == 24)
                .accessibilityLabel("Increase servings")
            }
            .tint(AppTheme.primaryGreen)
        }
    }

    private var nutritionSection: some View {
        Section {
            nutritionField("Protein", value: $proteinText)
            nutritionField("Carbohydrates", value: $carbsText)
            nutritionField("Fat", value: $fatText)
        } header: {
            Text("Macronutrients (optional)")
        } footer: {
            Text("Enter grams for \(baseServings) servings")
        }
    }

    private func nutritionField(_ title: String, value: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text("g").foregroundStyle(.secondary)
        }
    }

    private var vegetarianToggle: some View {
        Section {
            Toggle("Vegetarian", isOn: Binding(
                get: { categories.contains(.vegetarian) },
                set: { selected in
                    if selected { categories.insert(.vegetarian) }
                    else { categories.remove(.vegetarian) }
                }
            ))
            .tint(AppTheme.primaryGreen)
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
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 100)
                        Spacer(minLength: 0)
                        Button(role: .destructive) {
                            removeIngredient(id: ingredient.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 21))
                                .foregroundStyle(.red)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .disabled(ingredients.count == 1)
                        .accessibilityLabel("Remove ingredient \(ingredient.name)")
                        .accessibilityIdentifier("remove-ingredient-\(ingredient.id)")
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
            Text("A recipe needs at least one ingredient with a name and a quantity greater than zero.")
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
                        .buttonStyle(.borderless)
                }
                .padding(.vertical, 5)
            }
            Button { steps.append(StepDraft()) } label: {
                Label("Add preparation step", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Preparation (optional)")
        } footer: {
            Text("Write a separate step for every action, including cooking times and temperatures.")
        }
    }

    private func removeIngredient(id: String) {
        guard ingredients.count > 1 else { return }
        ingredients.removeAll { $0.id == id }
    }

    private func save() {
        guard isValid,
              let minutes = Int(minutesText.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let newIngredients = ingredients.map(\.stored)
        let protein = nutritionPerServing(proteinText)
        let carbs = nutritionPerServing(carbsText)
        let fat = nutritionPerServing(fatText)
        let categoriesList = RecipeClassification.categories(
            minutes: minutes, ingredients: newIngredients, protein: protein,
            carbs: carbs, fat: fat, chosen: categories).sorted { $0.rawValue < $1.rawValue }
        let newSteps = steps.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

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
            existing.calories = caloriesPerServing
            existing.proteinGrams = protein
            existing.carbsGrams = carbs
            existing.fatGrams = fat
            existing.baseServings = baseServings
            existing.categoryNames = categoriesList.map(\.rawValue)
            existing.ingredients = newIngredients
            existing.steps = newSteps
            existing.photoData = nil // Old SwiftData image bytes are no longer needed.
        } else {
            let newRecipe = StoredRecipe(
                id: "user-" + UUID().uuidString,
                title: trimmedTitle, minutes: minutes, calories: caloriesPerServing,
                imageName: chosenName, categories: categoriesList,
                ingredients: newIngredients, steps: newSteps,
                baseServings: baseServings, isUserCreated: true,
                proteinGrams: protein, carbsGrams: carbs, fatGrams: fat
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
