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

    // Nutrition stored per 100g (standard measure)
    var servingSize: Double  // Always 100g for consistency
    var servingSizeUnit: String

    // Portion information (optional - for multi-portion products like yogurt pots)
    var portionSize: Double?       // grams per single portion (e.g., 115g per pot)
    var portionsPerPackage: Int?   // number of portions in package (e.g., 4 pots)
    var calories: Double
    var protein: Double      // grams
    var carbohydrates: Double // grams
    var fat: Double          // grams
    var saturatedFat: Double? // grams
    var transFat: Double?    // grams
    var fibre: Double?       // grams (UK spelling)
    var sugar: Double?       // grams
    var sodium: Double?      // mg
    var cholesterol: Double? // mg

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
    var phosphorus: Double?  // mg
    var selenium: Double?    // mcg
    var copper: Double?      // mg
    var manganese: Double?   // mg

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

    // Calculate nutrition for a given amount in grams (nutrition stored per 100g)
    func nutritionFor(grams: Double) -> NutritionInfo {
        let multiplier = grams / 100.0  // Always divide by 100 since we store per 100g
        return NutritionInfo(
            calories: calories * multiplier,
            protein: protein * multiplier,
            carbohydrates: carbohydrates * multiplier,
            fat: fat * multiplier,
            fibre: (fibre ?? 0) * multiplier,
            sugar: (sugar ?? 0) * multiplier
        )
    }

    // Calculate nutrition for given number of portions
    func nutritionForPortions(_ portions: Double) -> NutritionInfo? {
        guard let portionGrams = portionSize else { return nil }
        let totalGrams = portionGrams * portions
        return nutritionFor(grams: totalGrams)
    }

    // Helper to get calories for a specific amount
    func caloriesFor(grams: Double) -> Double {
        return (calories / 100.0) * grams
    }

    // Helper to get calories per portion
    var caloriesPerPortion: Double? {
        guard let portionGrams = portionSize else { return nil }
        return (calories / 100.0) * portionGrams
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
