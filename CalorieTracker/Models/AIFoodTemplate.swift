// AIFoodTemplate.swift - Persistent storage for AI-generated food templates
// Made by mpcode

import Foundation
import SwiftData

/// Stores AI-generated foods separately from daily logs
/// so they persist even when deleted from today's food list
@Model
final class AIFoodTemplate {
    var id: UUID
    var name: String
    var amount: Double
    var unit: String

    // Nutrition per serving
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var sugar: Double
    var fibre: Double
    var sodium: Double

    // Vitamins (per the serving amount)
    var vitaminA: Double?
    var vitaminC: Double?
    var vitaminD: Double?
    var vitaminE: Double?
    var vitaminK: Double?
    var vitaminB1: Double?
    var vitaminB2: Double?
    var vitaminB3: Double?
    var vitaminB6: Double?
    var vitaminB12: Double?
    var folate: Double?

    // Minerals (per the serving amount)
    var calcium: Double?
    var iron: Double?
    var zinc: Double?
    var magnesium: Double?
    var potassium: Double?
    var phosphorus: Double?
    var selenium: Double?
    var copper: Double?
    var manganese: Double?

    // AI context
    var aiPrompt: String?

    // Usage tracking
    var dateCreated: Date
    var lastUsed: Date
    var useCount: Int

    init(
        name: String,
        amount: Double,
        unit: String,
        calories: Double,
        protein: Double = 0,
        carbohydrates: Double = 0,
        fat: Double = 0,
        sugar: Double = 0,
        fibre: Double = 0,
        sodium: Double = 0,
        aiPrompt: String? = nil,
        vitaminA: Double? = nil,
        vitaminC: Double? = nil,
        vitaminD: Double? = nil,
        vitaminE: Double? = nil,
        vitaminK: Double? = nil,
        vitaminB1: Double? = nil,
        vitaminB2: Double? = nil,
        vitaminB3: Double? = nil,
        vitaminB6: Double? = nil,
        vitaminB12: Double? = nil,
        folate: Double? = nil,
        calcium: Double? = nil,
        iron: Double? = nil,
        zinc: Double? = nil,
        magnesium: Double? = nil,
        potassium: Double? = nil,
        phosphorus: Double? = nil,
        selenium: Double? = nil,
        copper: Double? = nil,
        manganese: Double? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.unit = unit
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.sugar = sugar
        self.fibre = fibre
        self.sodium = sodium
        self.aiPrompt = aiPrompt
        self.vitaminA = vitaminA
        self.vitaminC = vitaminC
        self.vitaminD = vitaminD
        self.vitaminE = vitaminE
        self.vitaminK = vitaminK
        self.vitaminB1 = vitaminB1
        self.vitaminB2 = vitaminB2
        self.vitaminB3 = vitaminB3
        self.vitaminB6 = vitaminB6
        self.vitaminB12 = vitaminB12
        self.folate = folate
        self.calcium = calcium
        self.iron = iron
        self.zinc = zinc
        self.magnesium = magnesium
        self.potassium = potassium
        self.phosphorus = phosphorus
        self.selenium = selenium
        self.copper = copper
        self.manganese = manganese
        self.dateCreated = Date()
        self.lastUsed = Date()
        self.useCount = 1
    }

    /// Create template from QuickFoodEstimate (captures vitamins from AI)
    convenience init(from estimate: QuickFoodEstimate, prompt: String? = nil) {
        self.init(
            name: estimate.foodName,
            amount: estimate.amount,
            unit: estimate.unit,
            calories: estimate.calories,
            protein: estimate.protein,
            carbohydrates: estimate.carbohydrates,
            fat: estimate.fat,
            sugar: estimate.sugar ?? 0,
            fibre: estimate.fibre ?? 0,
            sodium: estimate.sodium ?? 0,
            aiPrompt: prompt,
            vitaminA: estimate.vitaminA,
            vitaminC: estimate.vitaminC,
            vitaminD: estimate.vitaminD,
            vitaminE: estimate.vitaminE,
            vitaminK: estimate.vitaminK,
            vitaminB1: estimate.vitaminB1,
            vitaminB2: estimate.vitaminB2,
            vitaminB3: estimate.vitaminB3,
            vitaminB6: estimate.vitaminB6,
            vitaminB12: estimate.vitaminB12,
            folate: estimate.folate,
            calcium: estimate.calcium,
            iron: estimate.iron,
            zinc: estimate.zinc,
            magnesium: estimate.magnesium,
            potassium: estimate.potassium,
            phosphorus: estimate.phosphorus,
            selenium: estimate.selenium,
            copper: estimate.copper,
            manganese: estimate.manganese
        )
    }

    /// Create a Product from this template (stores per 100g values)
    func createProduct() -> Product {
        // Convert from per-serving to per-100g
        // Assume amount is in grams for conversion
        let scale = 100.0 / max(amount, 1)

        let product = Product(
            name: name,
            servingSize: 100,
            servingSizeUnit: "g",
            calories: calories * scale,
            protein: protein * scale,
            carbohydrates: carbohydrates * scale,
            fat: fat * scale,
            isCustom: true
        )

        // Set additional nutrition (per 100g)
        product.sugar = sugar * scale
        product.fibre = fibre * scale
        product.sodium = sodium * scale

        // Set vitamins (per 100g)
        if let v = vitaminA { product.vitaminA = v * scale }
        if let v = vitaminC { product.vitaminC = v * scale }
        if let v = vitaminD { product.vitaminD = v * scale }
        if let v = vitaminE { product.vitaminE = v * scale }
        if let v = vitaminK { product.vitaminK = v * scale }
        if let v = vitaminB1 { product.vitaminB1 = v * scale }
        if let v = vitaminB2 { product.vitaminB2 = v * scale }
        if let v = vitaminB3 { product.vitaminB3 = v * scale }
        if let v = vitaminB6 { product.vitaminB6 = v * scale }
        if let v = vitaminB12 { product.vitaminB12 = v * scale }
        if let v = folate { product.folate = v * scale }

        // Set minerals (per 100g)
        if let v = calcium { product.calcium = v * scale }
        if let v = iron { product.iron = v * scale }
        if let v = zinc { product.zinc = v * scale }
        if let v = magnesium { product.magnesium = v * scale }
        if let v = potassium { product.potassium = v * scale }
        if let v = phosphorus { product.phosphorus = v * scale }
        if let v = selenium { product.selenium = v * scale }
        if let v = copper { product.copper = v * scale }
        if let v = manganese { product.manganese = v * scale }

        return product
    }

    /// Create a FoodEntry linked to a Product (for proper vitamin tracking)
    func createEntryWithProduct() -> (entry: FoodEntry, product: Product) {
        let product = createProduct()

        let entry = FoodEntry(
            product: product,
            amount: amount,
            unit: unit,
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            sugar: sugar,
            fibre: fibre,
            sodium: sodium,
            aiGenerated: true,
            aiPrompt: aiPrompt
        )

        return (entry, product)
    }

    /// Update usage tracking
    func recordUse() {
        lastUsed = Date()
        useCount += 1
    }
}
