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
        aiPrompt: String? = nil
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
        self.dateCreated = Date()
        self.lastUsed = Date()
        self.useCount = 1
    }

    /// Create template from a FoodEntry
    convenience init(from entry: FoodEntry) {
        self.init(
            name: entry.customFoodName ?? entry.displayName,
            amount: entry.amount,
            unit: entry.unit,
            calories: entry.calories,
            protein: entry.protein,
            carbohydrates: entry.carbohydrates,
            fat: entry.fat,
            sugar: entry.sugar,
            fibre: entry.fibre,
            sodium: entry.sodium,
            aiPrompt: entry.aiPrompt
        )
    }

    /// Create a FoodEntry from this template
    func createEntry() -> FoodEntry {
        return FoodEntry(
            customFoodName: name,
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
    }

    /// Update usage tracking
    func recordUse() {
        lastUsed = Date()
        useCount += 1
    }
}
