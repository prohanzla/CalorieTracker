// AIFoodTemplate.swift - Persistent storage for AI-generated food templates
// Made by mpcode

import Foundation
import SwiftData

/// Stores AI-generated foods separately from daily logs
/// so they persist even when deleted from today's food list
@Model
final class AIFoodTemplate {
    // CloudKit requires default values for all non-optional properties
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String?  // AI-suggested emoji for this food
    var amount: Double = 0
    var unit: String = "g"
    var weightInGrams: Double = 0  // Actual weight in grams for proper per-100g conversion

    // Nutrition per serving
    var calories: Double = 0
    var protein: Double = 0
    var carbohydrates: Double = 0
    var fat: Double = 0
    var sugar: Double = 0
    var naturalSugar: Double = 0  // From whole fruits, vegetables, dairy
    var addedSugar: Double = 0    // Added/processed sugars
    var fibre: Double = 0
    var sodium: Double = 0

    // Vitamins (per the serving amount)
    var vitaminA: Double?
    var vitaminC: Double?
    var vitaminD: Double?
    var vitaminE: Double?
    var vitaminK: Double?
    var vitaminB1: Double?
    var vitaminB2: Double?
    var vitaminB3: Double?
    var vitaminB5: Double?    // Pantothenic Acid
    var vitaminB6: Double?
    var vitaminB7: Double?    // Biotin
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
    var chromium: Double?
    var molybdenum: Double?
    var iodine: Double?
    var chloride: Double?

    // AI context
    var aiPrompt: String?

    // Usage tracking
    var dateCreated: Date = Date()
    var lastUsed: Date = Date()
    var useCount: Int = 0

    init(
        name: String,
        emoji: String? = nil,
        amount: Double,
        unit: String,
        weightInGrams: Double,
        calories: Double,
        protein: Double = 0,
        carbohydrates: Double = 0,
        fat: Double = 0,
        sugar: Double = 0,
        naturalSugar: Double = 0,
        addedSugar: Double = 0,
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
        vitaminB5: Double? = nil,
        vitaminB6: Double? = nil,
        vitaminB7: Double? = nil,
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
        manganese: Double? = nil,
        chromium: Double? = nil,
        molybdenum: Double? = nil,
        iodine: Double? = nil,
        chloride: Double? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.amount = amount
        self.unit = unit
        self.weightInGrams = weightInGrams
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.sugar = sugar
        self.naturalSugar = naturalSugar
        self.addedSugar = addedSugar
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
        self.vitaminB5 = vitaminB5
        self.vitaminB6 = vitaminB6
        self.vitaminB7 = vitaminB7
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
        self.chromium = chromium
        self.molybdenum = molybdenum
        self.iodine = iodine
        self.chloride = chloride
        self.dateCreated = Date()
        self.lastUsed = Date()
        self.useCount = 1
    }

    /// Create template from QuickFoodEstimate (captures vitamins and emoji from AI)
    convenience init(from estimate: QuickFoodEstimate, prompt: String? = nil) {
        self.init(
            name: estimate.foodName,
            emoji: estimate.emoji,
            amount: estimate.amount,
            unit: estimate.unit,
            weightInGrams: estimate.weightInGrams,
            calories: estimate.calories,
            protein: estimate.protein,
            carbohydrates: estimate.carbohydrates,
            fat: estimate.fat,
            sugar: estimate.sugar ?? 0,
            naturalSugar: estimate.naturalSugar ?? 0,
            addedSugar: estimate.addedSugar ?? 0,
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
            vitaminB5: estimate.vitaminB5,
            vitaminB6: estimate.vitaminB6,
            vitaminB7: estimate.vitaminB7,
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
            manganese: estimate.manganese,
            chromium: estimate.chromium,
            molybdenum: estimate.molybdenum,
            iodine: estimate.iodine,
            chloride: estimate.chloride
        )
    }

    /// Create a Product from this template (stores per 100g values)
    func createProduct() -> Product {
        // Convert from per-serving to per-100g
        // Use weightInGrams for accurate conversion (handles "piece" units correctly)
        let scale = 100.0 / max(weightInGrams, 1)

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

        // Set emoji from AI
        product.emoji = emoji

        // Set additional nutrition (per 100g)
        product.sugar = sugar * scale
        product.naturalSugar = naturalSugar * scale
        product.addedSugar = addedSugar * scale
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
        if let v = vitaminB5 { product.vitaminB5 = v * scale }
        if let v = vitaminB6 { product.vitaminB6 = v * scale }
        if let v = vitaminB7 { product.vitaminB7 = v * scale }
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
        if let v = chromium { product.chromium = v * scale }
        if let v = molybdenum { product.molybdenum = v * scale }
        if let v = iodine { product.iodine = v * scale }
        if let v = chloride { product.chloride = v * scale }

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
            naturalSugar: naturalSugar,
            addedSugar: addedSugar,
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
