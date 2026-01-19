// FoodEntry.swift - SwiftData model for individual food consumption entries
// Made by mpcode

import Foundation
import SwiftData

@Model
final class FoodEntry {
    // CloudKit requires default values for all non-optional properties
    var id: UUID = UUID()
    var product: Product?
    var productName: String?     // Stored at time of entry - persists even if product is deleted
    var customFoodName: String?  // For AI-generated entries like "one apple"
    var amount: Double = 0           // Amount consumed
    var unit: String = "g"             // g, ml, piece, etc.
    var timestamp: Date = Date()

    // Calculated nutrition at time of entry
    var calories: Double = 0
    var protein: Double = 0
    var carbohydrates: Double = 0
    var fat: Double = 0

    // Additional nutrition tracking (defaults for migration)
    var sugar: Double = 0           // Total sugar
    var naturalSugar: Double = 0    // Sugar from whole fruits, vegetables, dairy
    var addedSugar: Double = 0      // Added/processed sugars (counts against daily limit)
    var fibre: Double = 0
    var sodium: Double = 0  // in mg

    // For AI-generated entries without a product
    var aiGenerated: Bool = false
    var aiPrompt: String?        // Original prompt like "I had one apple"

    // Vitamin/mineral data stored as JSON dictionary (persists even if product deleted)
    // Format: ["vitaminA": 100.0, "calcium": 50.0, ...]
    var nutrientData: Data?

    @Relationship
    var dailyLog: DailyLog?

    // MARK: - Nutrient Data Helpers

    /// Get stored nutrients as dictionary
    var nutrients: [String: Double] {
        get {
            guard let data = nutrientData,
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            nutrientData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Get a specific nutrient value by ID
    func nutrientValue(for id: String) -> Double? {
        nutrients[id]
    }

    /// Capture all nutrient values from a product (scaled to amount consumed)
    private static func captureNutrients(from product: Product, scale: Double) -> [String: Double] {
        var nutrients: [String: Double] = [:]
        let nutrientIds = [
            "vitaminA", "vitaminC", "vitaminD", "vitaminE", "vitaminK",
            "vitaminB1", "vitaminB2", "vitaminB3", "vitaminB5", "vitaminB6",
            "vitaminB7", "vitaminB12", "folate",
            "calcium", "iron", "zinc", "magnesium", "potassium", "phosphorus",
            "selenium", "copper", "manganese", "chromium", "molybdenum", "iodine", "chloride"
        ]
        for id in nutrientIds {
            if let value = product.nutrientValue(for: id) {
                nutrients[id] = value * scale
            }
        }
        return nutrients
    }

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
        naturalSugar: Double = 0,
        addedSugar: Double = 0,
        fibre: Double = 0,
        sodium: Double = 0,
        aiGenerated: Bool = false,
        aiPrompt: String? = nil
    ) {
        self.id = UUID()
        self.product = product
        self.productName = product?.name  // Store name at time of entry
        self.customFoodName = customFoodName
        self.amount = amount
        self.unit = unit
        self.timestamp = Date()
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.sugar = sugar
        self.naturalSugar = naturalSugar
        self.addedSugar = addedSugar
        self.fibre = fibre
        self.sodium = sodium
        self.aiGenerated = aiGenerated
        self.aiPrompt = aiPrompt

        // Capture vitamin/mineral data from product (scaled to amount consumed)
        if let product = product {
            let scale = amount / 100.0  // Products store values per 100g
            let capturedNutrients = Self.captureNutrients(from: product, scale: scale)
            if !capturedNutrients.isEmpty {
                self.nutrientData = try? JSONEncoder().encode(capturedNutrients)
            }
        }
    }

    var displayName: String {
        // Priority: live product name > stored product name > custom food name > fallback
        if let product = product {
            return product.name
        }
        if let storedName = productName {
            return storedName
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
        naturalSugar = naturalSugar * ratio
        addedSugar = addedSugar * ratio
        fibre = fibre * ratio
        sodium = sodium * ratio

        // Scale vitamin/mineral data too
        scaleNutrients(by: ratio)
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
        naturalSugar = naturalSugar * ratio
        addedSugar = addedSugar * ratio
        fibre = fibre * ratio
        sodium = sodium * ratio

        // Scale vitamin/mineral data too
        scaleNutrients(by: ratio)
    }

    /// Scale all stored nutrient values by a ratio
    private func scaleNutrients(by ratio: Double) {
        var scaled = nutrients
        for (key, value) in scaled {
            scaled[key] = value * ratio
        }
        nutrients = scaled
    }
}
