// Product.swift - SwiftData model for scanned/added products
// Made by mpcode

import Foundation
import SwiftData

@Model
final class Product {
    var id: UUID
    var name: String
    var barcode: String?
    var brand: String?

    // Nutrition per serving
    var servingSize: Double  // in grams
    var servingSizeUnit: String
    var calories: Double
    var protein: Double      // grams
    var carbohydrates: Double // grams
    var fat: Double          // grams
    var saturatedFat: Double? // grams
    var fibre: Double?       // grams (UK spelling)
    var sugar: Double?       // grams
    var sodium: Double?      // mg

    // Vitamins (percentage of daily value or mg)
    var vitaminA: Double?
    var vitaminC: Double?
    var vitaminD: Double?
    var vitaminE: Double?
    var vitaminK: Double?
    var vitaminB1: Double?   // Thiamin
    var vitaminB2: Double?   // Riboflavin
    var vitaminB3: Double?   // Niacin
    var vitaminB6: Double?
    var vitaminB12: Double?
    var folate: Double?

    // Minerals
    var calcium: Double?     // mg
    var iron: Double?        // mg
    var potassium: Double?   // mg
    var magnesium: Double?   // mg
    var zinc: Double?        // mg

    var imageData: Data?     // Store product image
    var dateAdded: Date
    var isCustom: Bool       // True if manually added without barcode

    @Relationship(deleteRule: .cascade, inverse: \FoodEntry.product)
    var entries: [FoodEntry]?

    init(
        name: String,
        barcode: String? = nil,
        brand: String? = nil,
        servingSize: Double = 100,
        servingSizeUnit: String = "g",
        calories: Double = 0,
        protein: Double = 0,
        carbohydrates: Double = 0,
        fat: Double = 0,
        isCustom: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.barcode = barcode
        self.brand = brand
        self.servingSize = servingSize
        self.servingSizeUnit = servingSizeUnit
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.isCustom = isCustom
        self.dateAdded = Date()
    }

    // Calculate nutrition for a given amount
    func nutritionFor(amount: Double, unit: String = "g") -> NutritionInfo {
        let multiplier = amount / servingSize
        return NutritionInfo(
            calories: calories * multiplier,
            protein: protein * multiplier,
            carbohydrates: carbohydrates * multiplier,
            fat: fat * multiplier,
            fibre: (fibre ?? 0) * multiplier,
            sugar: (sugar ?? 0) * multiplier
        )
    }
}

struct NutritionInfo {
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fibre: Double
    let sugar: Double
}
