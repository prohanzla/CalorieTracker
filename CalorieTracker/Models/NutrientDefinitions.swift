// NutrientDefinitions.swift - Centralised vitamin and mineral definitions
// Made by mpcode
// Single source of truth for all nutrient data - update here to change everywhere

import Foundation

/// Represents a single nutrient (vitamin or mineral) with all its metadata
struct NutrientDefinition: Identifiable {
    let id: String              // Unique identifier (e.g., "vitaminA", "calcium")
    let name: String            // Full name (e.g., "Vitamin A", "Calcium")
    let shortName: String       // Abbreviated name for compact display (e.g., "A", "Calcium")
    let unit: String            // Unit of measurement (e.g., "mcg", "mg")
    let target: Double          // Daily recommended intake (RDA/AI)
    let upperLimit: Double?     // Tolerable upper intake level (nil if no limit)
    let category: NutrientCategory
    let jsonKey: String         // Key used in AI JSON responses
    let decimalPlaces: Int      // How many decimal places to display

    enum NutrientCategory {
        case vitamin
        case mineral
    }
}

/// Centralised definitions for all vitamins and minerals
/// Update this list to add/modify nutrients across the entire app
struct NutrientDefinitions {

    // MARK: - All Vitamins
    static let vitamins: [NutrientDefinition] = [
        NutrientDefinition(
            id: "vitaminA", name: "Vitamin A", shortName: "A",
            unit: "mcg", target: 800, upperLimit: 3000,
            category: .vitamin, jsonKey: "vitaminA", decimalPlaces: 1
        ),
        NutrientDefinition(
            id: "vitaminC", name: "Vitamin C", shortName: "C",
            unit: "mg", target: 80, upperLimit: 2000,
            category: .vitamin, jsonKey: "vitaminC", decimalPlaces: 1
        ),
        NutrientDefinition(
            id: "vitaminD", name: "Vitamin D", shortName: "D",
            unit: "mcg", target: 10, upperLimit: 100,
            category: .vitamin, jsonKey: "vitaminD", decimalPlaces: 1
        ),
        NutrientDefinition(
            id: "vitaminE", name: "Vitamin E", shortName: "E",
            unit: "mg", target: 12, upperLimit: 540,
            category: .vitamin, jsonKey: "vitaminE", decimalPlaces: 2
        ),
        NutrientDefinition(
            id: "vitaminK", name: "Vitamin K", shortName: "K",
            unit: "mcg", target: 75, upperLimit: nil,
            category: .vitamin, jsonKey: "vitaminK", decimalPlaces: 1
        ),
        NutrientDefinition(
            id: "vitaminB1", name: "Vitamin B1 (Thiamin)", shortName: "B1",
            unit: "mg", target: 1.1, upperLimit: nil,
            category: .vitamin, jsonKey: "vitaminB1", decimalPlaces: 3
        ),
        NutrientDefinition(
            id: "vitaminB2", name: "Vitamin B2 (Riboflavin)", shortName: "B2",
            unit: "mg", target: 1.4, upperLimit: nil,
            category: .vitamin, jsonKey: "vitaminB2", decimalPlaces: 3
        ),
        NutrientDefinition(
            id: "vitaminB3", name: "Vitamin B3 (Niacin)", shortName: "B3",
            unit: "mg", target: 16, upperLimit: 35,
            category: .vitamin, jsonKey: "vitaminB3", decimalPlaces: 1
        ),
        NutrientDefinition(
            id: "vitaminB5", name: "Vitamin B5 (Pantothenic Acid)", shortName: "B5",
            unit: "mg", target: 5, upperLimit: nil,
            category: .vitamin, jsonKey: "vitaminB5", decimalPlaces: 2
        ),
        NutrientDefinition(
            id: "vitaminB6", name: "Vitamin B6", shortName: "B6",
            unit: "mg", target: 1.4, upperLimit: 25,
            category: .vitamin, jsonKey: "vitaminB6", decimalPlaces: 2
        ),
        NutrientDefinition(
            id: "vitaminB7", name: "Vitamin B7 (Biotin)", shortName: "B7",
            unit: "mcg", target: 30, upperLimit: nil,
            category: .vitamin, jsonKey: "vitaminB7", decimalPlaces: 1
        ),
        NutrientDefinition(
            id: "vitaminB12", name: "Vitamin B12", shortName: "B12",
            unit: "mcg", target: 2.5, upperLimit: nil,
            category: .vitamin, jsonKey: "vitaminB12", decimalPlaces: 2
        ),
        NutrientDefinition(
            id: "folate", name: "Folate (B9)", shortName: "Folate",
            unit: "mcg", target: 400, upperLimit: 1000,
            category: .vitamin, jsonKey: "folate", decimalPlaces: 1
        )
    ]

    // MARK: - All Minerals
    static let minerals: [NutrientDefinition] = [
        NutrientDefinition(
            id: "calcium", name: "Calcium", shortName: "Calcium",
            unit: "mg", target: 1000, upperLimit: 2500,
            category: .mineral, jsonKey: "calcium", decimalPlaces: 0
        ),
        NutrientDefinition(
            id: "iron", name: "Iron", shortName: "Iron",
            unit: "mg", target: 14, upperLimit: 45,
            category: .mineral, jsonKey: "iron", decimalPlaces: 1
        ),
        NutrientDefinition(
            id: "zinc", name: "Zinc", shortName: "Zinc",
            unit: "mg", target: 10, upperLimit: 25,
            category: .mineral, jsonKey: "zinc", decimalPlaces: 1
        ),
        NutrientDefinition(
            id: "magnesium", name: "Magnesium", shortName: "Magnes.",
            unit: "mg", target: 375, upperLimit: 400,
            category: .mineral, jsonKey: "magnesium", decimalPlaces: 0
        ),
        NutrientDefinition(
            id: "potassium", name: "Potassium", shortName: "Potass.",
            unit: "mg", target: 3500, upperLimit: 6000,
            category: .mineral, jsonKey: "potassium", decimalPlaces: 0
        ),
        NutrientDefinition(
            id: "phosphorus", name: "Phosphorus", shortName: "Phosph.",
            unit: "mg", target: 700, upperLimit: 4000,
            category: .mineral, jsonKey: "phosphorus", decimalPlaces: 0
        ),
        NutrientDefinition(
            id: "selenium", name: "Selenium", shortName: "Selenium",
            unit: "mcg", target: 55, upperLimit: 400,
            category: .mineral, jsonKey: "selenium", decimalPlaces: 1
        ),
        NutrientDefinition(
            id: "copper", name: "Copper", shortName: "Copper",
            unit: "mg", target: 1, upperLimit: 5,
            category: .mineral, jsonKey: "copper", decimalPlaces: 2
        ),
        NutrientDefinition(
            id: "manganese", name: "Manganese", shortName: "Mangan.",
            unit: "mg", target: 2, upperLimit: 11,
            category: .mineral, jsonKey: "manganese", decimalPlaces: 2
        ),
        NutrientDefinition(
            id: "chromium", name: "Chromium", shortName: "Chromium",
            unit: "mcg", target: 35, upperLimit: nil,
            category: .mineral, jsonKey: "chromium", decimalPlaces: 1
        ),
        NutrientDefinition(
            id: "molybdenum", name: "Molybdenum", shortName: "Molyb.",
            unit: "mcg", target: 45, upperLimit: 2000,
            category: .mineral, jsonKey: "molybdenum", decimalPlaces: 1
        ),
        NutrientDefinition(
            id: "iodine", name: "Iodine", shortName: "Iodine",
            unit: "mcg", target: 150, upperLimit: 1100,
            category: .mineral, jsonKey: "iodine", decimalPlaces: 1
        ),
        NutrientDefinition(
            id: "chloride", name: "Chloride", shortName: "Chloride",
            unit: "mg", target: 2300, upperLimit: 3600,
            category: .mineral, jsonKey: "chloride", decimalPlaces: 0
        )
    ]

    // MARK: - Combined Lists
    static var all: [NutrientDefinition] {
        vitamins + minerals
    }

    // MARK: - Lookup by ID
    static func nutrient(for id: String) -> NutrientDefinition? {
        all.first { $0.id == id }
    }

    // MARK: - Generate AI Prompt JSON Schema
    /// Generates the JSON schema portion for AI prompts
    /// Usage: Include this in your AI prompt to describe expected response format
    static func aiPromptSchema(perUnit: String = "100g") -> String {
        var lines: [String] = []

        for nutrient in vitamins {
            lines.append("\"\(nutrient.jsonKey)\": number in \(nutrient.unit) (per \(perUnit)) or null,")
        }
        for nutrient in minerals {
            lines.append("\"\(nutrient.jsonKey)\": number in \(nutrient.unit) (per \(perUnit)) or null,")
        }

        return lines.joined(separator: "\n")
    }

    /// Generates the complete nutrient fields for AI JSON responses
    static var aiNutrientFields: String {
        """
        "vitaminA": number in mcg (per 100g) or null,
        "vitaminC": number in mg (per 100g) or null,
        "vitaminD": number in mcg (per 100g) or null,
        "vitaminE": number in mg (per 100g) or null,
        "vitaminK": number in mcg (per 100g) or null,
        "vitaminB1": number in mg (per 100g) or null (thiamin),
        "vitaminB2": number in mg (per 100g) or null (riboflavin),
        "vitaminB3": number in mg (per 100g) or null (niacin),
        "vitaminB5": number in mg (per 100g) or null (pantothenic acid),
        "vitaminB6": number in mg (per 100g) or null,
        "vitaminB7": number in mcg (per 100g) or null (biotin),
        "vitaminB12": number in mcg (per 100g) or null,
        "folate": number in mcg (per 100g) or null,
        "calcium": number in mg (per 100g) or null,
        "iron": number in mg (per 100g) or null,
        "zinc": number in mg (per 100g) or null,
        "magnesium": number in mg (per 100g) or null,
        "potassium": number in mg (per 100g) or null,
        "phosphorus": number in mg (per 100g) or null,
        "selenium": number in mcg (per 100g) or null,
        "copper": number in mg (per 100g) or null,
        "manganese": number in mg (per 100g) or null,
        "chromium": number in mcg (per 100g) or null,
        "molybdenum": number in mcg (per 100g) or null,
        "iodine": number in mcg (per 100g) or null,
        "chloride": number in mg (per 100g) or null
        """
    }
}

// MARK: - Product KeyPath Extension
extension Product {
    /// Get nutrient value by definition ID
    func nutrientValue(for id: String) -> Double? {
        switch id {
        case "vitaminA": return vitaminA
        case "vitaminC": return vitaminC
        case "vitaminD": return vitaminD
        case "vitaminE": return vitaminE
        case "vitaminK": return vitaminK
        case "vitaminB1": return vitaminB1
        case "vitaminB2": return vitaminB2
        case "vitaminB3": return vitaminB3
        case "vitaminB5": return vitaminB5
        case "vitaminB6": return vitaminB6
        case "vitaminB7": return vitaminB7
        case "vitaminB12": return vitaminB12
        case "folate": return folate
        case "calcium": return calcium
        case "iron": return iron
        case "zinc": return zinc
        case "magnesium": return magnesium
        case "potassium": return potassium
        case "phosphorus": return phosphorus
        case "selenium": return selenium
        case "copper": return copper
        case "manganese": return manganese
        case "chromium": return chromium
        case "molybdenum": return molybdenum
        case "iodine": return iodine
        case "chloride": return chloride
        default: return nil
        }
    }

    /// Set nutrient value by definition ID
    func setNutrientValue(_ value: Double?, for id: String) {
        switch id {
        case "vitaminA": vitaminA = value
        case "vitaminC": vitaminC = value
        case "vitaminD": vitaminD = value
        case "vitaminE": vitaminE = value
        case "vitaminK": vitaminK = value
        case "vitaminB1": vitaminB1 = value
        case "vitaminB2": vitaminB2 = value
        case "vitaminB3": vitaminB3 = value
        case "vitaminB5": vitaminB5 = value
        case "vitaminB6": vitaminB6 = value
        case "vitaminB7": vitaminB7 = value
        case "vitaminB12": vitaminB12 = value
        case "folate": folate = value
        case "calcium": calcium = value
        case "iron": iron = value
        case "zinc": zinc = value
        case "magnesium": magnesium = value
        case "potassium": potassium = value
        case "phosphorus": phosphorus = value
        case "selenium": selenium = value
        case "copper": copper = value
        case "manganese": manganese = value
        case "chromium": chromium = value
        case "molybdenum": molybdenum = value
        case "iodine": iodine = value
        case "chloride": chloride = value
        default: break
        }
    }
}
