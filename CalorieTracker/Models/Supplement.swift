// Supplement.swift - SwiftData model for supplements/vitamins/pills
// Made by mpcode

import Foundation
import SwiftData
import UIKit
import SwiftUI

@Model
final class Supplement {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String?
    var dosageForm: String = "tablet"  // tablet, capsule, softgel, gummy, liquid, powder
    var servingSize: Double = 1        // Number of tablets/capsules per serving
    var servingSizeUnit: String = "tablet"

    // Optional info
    var notes: String?
    var imageData: Data?
    var dateAdded: Date = Date()

    // Vitamins (per serving)
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

    // Minerals (per serving)
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

    // Relationship to entries
    @Relationship(deleteRule: .nullify, inverse: \SupplementEntry.supplement)
    var entries: [SupplementEntry]?

    init(
        name: String,
        brand: String? = nil,
        dosageForm: String = "tablet",
        servingSize: Double = 1,
        servingSizeUnit: String = "tablet"
    ) {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.dosageForm = dosageForm
        self.servingSize = servingSize
        self.servingSizeUnit = servingSizeUnit
        self.dateAdded = Date()
    }

    /// Returns true if this supplement has any vitamin or mineral data
    var hasNutrientData: Bool {
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

    /// Returns the display image if available
    var displayImage: UIImage? {
        if let data = imageData {
            return UIImage(data: data)
        }
        return nil
    }

    /// Icon for the dosage form
    var dosageFormIcon: String {
        switch dosageForm.lowercased() {
        case "tablet": return "pill.fill"
        case "capsule": return "capsule.fill"
        case "softgel": return "capsule.fill"
        case "gummy": return "heart.fill"
        case "liquid": return "drop.fill"
        case "powder": return "sparkles"
        default: return "pill.fill"
        }
    }
}

// MARK: - Supplement Nutrient Access
extension Supplement {
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

// MARK: - Dosage Form Options
extension Supplement {
    static let dosageForms = [
        "tablet",
        "capsule",
        "softgel",
        "gummy",
        "liquid",
        "powder"
    ]
}
