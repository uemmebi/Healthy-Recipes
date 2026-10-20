//
//  UserRecipe.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import Foundation
import SwiftData

@Model
final class UserRecipe {
    @Attribute(.unique) var id: String
    var title: String
    var minutes: Int
    var calories: Int?
    var categoryNames: [String]
    var ingredientsText: String
    var stepsText: String
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date
    
    init(
        title: String,
        minutes: Int,
        calories: Int?,
        categoryNames: [String],
        ingredientsText: String,
        stepsText: String,
        photoData: Data?
    ) {
        self.id = "user-" + UUID().uuidString
        self.title = title
        self.minutes = minutes
        self.calories = calories
        self.categoryNames = categoryNames
        self.ingredientsText = ingredientsText
        self.stepsText = stepsText
        self.photoData = photoData
        self.createdAt = .now
    }
}
