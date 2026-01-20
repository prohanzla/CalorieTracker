// SupplementEntry.swift - SwiftData model for daily supplement intake entries
// Made by mpcode

import Foundation
import SwiftData

@Model
final class SupplementEntry {
    var id: UUID = UUID()
    var supplement: Supplement?
    var supplementName: String?  // Stored at time of entry - persists even if supplement is deleted
    var amount: Double = 1       // Number of servings taken (e.g., 2 tablets)
    var unit: String = "tablet"  // tablet, capsule, ml, scoop, etc.
    var timestamp: Date = Date()

    // Vitamin/mineral data stored as JSON dictionary (persists even if supplement deleted)
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

    /// Capture all nutrient values from a supplement (scaled to amount consumed)
    private static func captureNutrients(from supplement: Supplement, scale: Double) -> [String: Double] {
        var nutrients: [String: Double] = [:]
        let nutrientIds = [
            "vitaminA", "vitaminC", "vitaminD", "vitaminE", "vitaminK",
            "vitaminB1", "vitaminB2", "vitaminB3", "vitaminB5", "vitaminB6",
            "vitaminB7", "vitaminB12", "folate",
            "calcium", "iron", "zinc", "magnesium", "potassium", "phosphorus",
            "selenium", "copper", "manganese", "chromium", "molybdenum", "iodine", "chloride"
        ]
        for id in nutrientIds {
            if let value = supplement.nutrientValue(for: id) {
                nutrients[id] = value * scale
            }
        }
        return nutrients
    }

    init(
        supplement: Supplement? = nil,
        amount: Double = 1,
        unit: String = "tablet"
    ) {
        self.id = UUID()
        self.supplement = supplement
        self.supplementName = supplement?.name
        self.amount = amount
        self.unit = unit
        self.timestamp = Date()

        // Capture nutrient data from supplement at time of entry
        // Scale = amount / servingSize (e.g., 2 tablets / 1 tablet per serving = 2x)
        if let supplement = supplement {
            let scale = amount / supplement.servingSize
            let capturedNutrients = Self.captureNutrients(from: supplement, scale: scale)
            if !capturedNutrients.isEmpty {
                self.nutrientData = try? JSONEncoder().encode(capturedNutrients)
            }
        }
    }

    /// Display name - uses stored name if supplement was deleted
    var displayName: String {
        if let name = supplementName, !name.isEmpty {
            return name
        }
        return supplement?.name ?? "Unknown Supplement"
    }
}
