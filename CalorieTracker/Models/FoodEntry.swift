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

    // Additional nutrition tracking (defaults for migration)
    var sugar: Double = 0
    var fibre: Double = 0
    var sodium: Double = 0  // in mg

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
        sugar: Double = 0,
        fibre: Double = 0,
        sodium: Double = 0,
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
        self.sugar = sugar
        self.fibre = fibre
        self.sodium = sodium
        self.aiGenerated = aiGenerated
        self.aiPrompt = aiPrompt
    }

    var displayName: String {
        if let product = product {
            return product.name
        }
        return customFoodName ?? "Unknown food"
    }

    // Nutrition per unit (for proportional adjustments)
    var caloriesPerUnit: Double {
        guard amount > 0 else { return 0 }
        return calories / amount
    }

    var proteinPerUnit: Double {
        guard amount > 0 else { return 0 }
        return protein / amount
    }

    var carbsPerUnit: Double {
        guard amount > 0 else { return 0 }
        return carbohydrates / amount
    }

    var fatPerUnit: Double {
        guard amount > 0 else { return 0 }
        return fat / amount
    }

    /// Adjust amount and recalculate nutrition proportionally
    func adjustAmount(by delta: Double) {
        let newAmount = max(1, amount + delta)
        let ratio = newAmount / amount

        amount = newAmount
        calories = calories * ratio
        protein = protein * ratio
        carbohydrates = carbohydrates * ratio
        fat = fat * ratio
        sugar = sugar * ratio
        fibre = fibre * ratio
        sodium = sodium * ratio
    }

    /// Set amount and recalculate nutrition proportionally
    func setAmount(_ newAmount: Double) {
        guard newAmount > 0, amount > 0 else { return }
        let ratio = newAmount / amount

        amount = newAmount
        calories = calories * ratio
        protein = protein * ratio
        carbohydrates = carbohydrates * ratio
        fat = fat * ratio
        sugar = sugar * ratio
        fibre = fibre * ratio
        sodium = sodium * ratio
    }
}
