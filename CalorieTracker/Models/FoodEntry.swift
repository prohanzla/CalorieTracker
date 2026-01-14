// FoodEntry.swift - SwiftData model for individual food consumption entries
// Made by mpcode

import Foundation
import SwiftData

@Model
final class FoodEntry {
    var id: UUID
    var product: Product?
    var customFoodName: String?  // For AI-generated entries like "one apple"
    var amount: Double           // Amount consumed
    var unit: String             // g, ml, piece, etc.
    var timestamp: Date

    // Calculated nutrition at time of entry
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double

    // For AI-generated entries without a product
    var aiGenerated: Bool
    var aiPrompt: String?        // Original prompt like "I had one apple"

    @Relationship
    var dailyLog: DailyLog?

    init(
        product: Product? = nil,
        customFoodName: String? = nil,
        amount: Double,
        unit: String = "g",
        calories: Double,
        protein: Double = 0,
        carbohydrates: Double = 0,
        fat: Double = 0,
        aiGenerated: Bool = false,
        aiPrompt: String? = nil
    ) {
        self.id = UUID()
        self.product = product
        self.customFoodName = customFoodName
        self.amount = amount
        self.unit = unit
        self.timestamp = Date()
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.aiGenerated = aiGenerated
        self.aiPrompt = aiPrompt
    }

    var displayName: String {
        if let product = product {
            return product.name
        }
        return customFoodName ?? "Unknown food"
    }
}
