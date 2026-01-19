// Product.swift - SwiftData model for scanned/added products
// Made by mpcode

import Foundation
import SwiftData
import UIKit
import SwiftUI

@Model
final class Product {
    // CloudKit requires default values for all non-optional properties
    var id: UUID = UUID()
    var name: String = ""
    var barcode: String?
    var brand: String?
    var emoji: String?  // AI-suggested emoji for this food

    // Nutrition stored per 100g (standard measure)
    var servingSize: Double = 100  // Always 100g for consistency
    var servingSizeUnit: String = "g"

    // Portion information (optional - for multi-portion products like yogurt pots)
    var portionSize: Double?       // grams per single portion (e.g., 115g per pot)
    var portionsPerPackage: Int?   // number of portions in package (e.g., 4 pots)
    var calories: Double = 0
    var protein: Double = 0      // grams
    var carbohydrates: Double = 0 // grams
    var fat: Double = 0          // grams
    var saturatedFat: Double? // grams
    var transFat: Double?    // grams
    var fibre: Double?       // grams (UK spelling)
    var sugar: Double?       // grams (total sugar)
    var naturalSugar: Double?  // grams (from whole fruits, vegetables, dairy)
    var addedSugar: Double?    // grams (added/processed sugars - counts against daily limit)
    var sodium: Double?      // mg
    var cholesterol: Double? // mg

    // Vitamins (percentage of daily value or mg)
    var vitaminA: Double?     // mcg
    var vitaminC: Double?     // mg
    var vitaminD: Double?     // mcg
    var vitaminE: Double?     // mg
    var vitaminK: Double?     // mcg
    var vitaminB1: Double?    // mg (Thiamin)
    var vitaminB2: Double?    // mg (Riboflavin)
    var vitaminB3: Double?    // mg (Niacin)
    var vitaminB5: Double?    // mg (Pantothenic Acid)
    var vitaminB6: Double?    // mg
    var vitaminB7: Double?    // mcg (Biotin)
    var vitaminB12: Double?   // mcg
    var folate: Double?       // mcg

    // Minerals
    var calcium: Double?      // mg
    var iron: Double?         // mg
    var potassium: Double?    // mg
    var magnesium: Double?    // mg
    var zinc: Double?         // mg
    var phosphorus: Double?   // mg
    var selenium: Double?     // mcg
    var copper: Double?       // mg
    var manganese: Double?    // mg
    var chromium: Double?     // mcg
    var molybdenum: Double?   // mcg
    var iodine: Double?       // mcg
    var chloride: Double?     // mg

    var imageData: Data?           // Store nutrition label image
    var mainImageData: Data?       // Store main product photo (shown in lists)
    var notes: String?             // User notes about this product
    var dateAdded: Date = Date()
    var isCustom: Bool = false             // True if manually added without barcode

    @Relationship(deleteRule: .nullify, inverse: \FoodEntry.product)
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

// MARK: - Product Extension for Vitamin Checking
extension Product {
    /// Returns true if this product has any vitamin or mineral data
    var hasVitaminData: Bool {
        vitaminA != nil || vitaminC != nil || vitaminD != nil ||
        vitaminE != nil || vitaminK != nil || vitaminB1 != nil ||
        vitaminB2 != nil || vitaminB3 != nil || vitaminB5 != nil ||
        vitaminB6 != nil || vitaminB7 != nil || vitaminB12 != nil ||
        folate != nil || calcium != nil || iron != nil ||
        potassium != nil || magnesium != nil || zinc != nil ||
        phosphorus != nil || selenium != nil || copper != nil ||
        manganese != nil || chromium != nil || molybdenum != nil ||
        iodine != nil || chloride != nil
    }
}

// MARK: - Product Extension for Display
extension Product {
    /// Returns the best available image for display (main photo > nutrition label)
    var displayImage: UIImage? {
        if let mainData = mainImageData, let image = UIImage(data: mainData) {
            return image
        }
        if let imageData = imageData, let image = UIImage(data: imageData) {
            return image
        }
        return nil
    }

    /// Returns an appropriate emoji for this product
    var displayEmoji: String {
        FoodEmojiMapper.emoji(for: name, productEmoji: emoji)
    }

    /// Returns an appropriate color for this product
    var displayColor: Color {
        FoodEmojiMapper.color(for: name)
    }
}
