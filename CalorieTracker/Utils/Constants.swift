// Constants.swift - Centralised app constants
// Made by mpcode

import Foundation

/// Centralised constants used throughout the app
struct Constants {

    // MARK: - UI Constants
    struct UI {
        static let defaultCornerRadius: CGFloat = 20
        static let smallCornerRadius: CGFloat = 12
        static let cardCornerRadius: CGFloat = 16
        static let buttonCornerRadius: CGFloat = 14
        static let tabBarHeight: CGFloat = 83
    }

    // MARK: - Nutrition Defaults
    struct Nutrition {
        // Daily recommended values (used in MacroCard and VitaminIndicator)
        static let proteinTargetMale: Double = 56
        static let proteinTargetFemale: Double = 46
        static let carbsTargetMale: Double = 300
        static let carbsTargetFemale: Double = 225
        static let fatTargetMale: Double = 78
        static let fatTargetFemale: Double = 65
        static let fiberTarget: Double = 25
        static let sugarTargetMale: Double = 36
        static let sugarTargetFemale: Double = 25
        static let sodiumTarget: Double = 2300

        // Default calorie target
        static let defaultCalorieTarget: Double = 2000

        // Input validation ranges
        static let calorieRange: ClosedRange<Double> = 1000...5000
        static let proteinRange: ClosedRange<Double> = 20...300
        static let carbsRange: ClosedRange<Double> = 50...500
        static let fatRange: ClosedRange<Double> = 20...200
        static let maxServingGrams: Double = 5000

        // Macro split percentages (standard)
        static let proteinPercentage: Double = 0.30
        static let carbsPercentage: Double = 0.40
        static let fatPercentage: Double = 0.30

        // Calories per gram
        static let caloriesPerGramProtein: Double = 4
        static let caloriesPerGramCarbs: Double = 4
        static let caloriesPerGramFat: Double = 9
    }

    // MARK: - Vitamin Daily Values (for progress indicators)
    struct Vitamins {
        static let vitaminA: Double = 900      // mcg
        static let vitaminC: Double = 90       // mg
        static let vitaminD: Double = 20       // mcg
        static let vitaminE: Double = 15       // mg
        static let vitaminK: Double = 120      // mcg
        static let vitaminB1: Double = 1.2     // mg (Thiamine)
        static let vitaminB2: Double = 1.3     // mg (Riboflavin)
        static let vitaminB3: Double = 16      // mg (Niacin)
        static let vitaminB6: Double = 1.7     // mg
        static let vitaminB12: Double = 2.4    // mcg
        static let folate: Double = 400        // mcg
        static let calcium: Double = 1000      // mg
        static let iron: Double = 18           // mg
        static let zinc: Double = 11           // mg
        static let magnesium: Double = 420     // mg
        static let potassium: Double = 4700    // mg
        static let phosphorus: Double = 700    // mg
        static let selenium: Double = 55       // mcg
        static let copper: Double = 0.9        // mg
        static let manganese: Double = 2.3     // mg
    }

    // MARK: - Profile Validation
    struct Profile {
        static let minAge: Int = 13
        static let maxAge: Int = 120
        static let minHeightCm: Double = 50
        static let maxHeightCm: Double = 300
        static let minHeightInches: Double = 20
        static let maxHeightInches: Double = 120
        static let minWeightKg: Double = 20
        static let maxWeightKg: Double = 500
        static let minWeightLbs: Double = 44
        static let maxWeightLbs: Double = 1100
    }

    // MARK: - BMR Calculation
    struct BMR {
        // Mifflin-St Jeor equation constants
        static let weightMultiplier: Double = 10
        static let heightMultiplier: Double = 6.25
        static let ageMultiplier: Double = 5
        static let maleConstant: Double = 5
        static let femaleConstant: Double = -161

        // Activity multipliers
        static let sedentaryMultiplier: Double = 1.2
        static let lightlyActiveMultiplier: Double = 1.375
        static let moderatelyActiveMultiplier: Double = 1.55
        static let veryActiveMultiplier: Double = 1.725
        static let extraActiveMultiplier: Double = 1.9
    }

    // MARK: - Animation
    struct Animation {
        static let defaultDuration: Double = 0.3
        static let springDuration: Double = 0.5
        static let pulseInterval: Double = 1.2
    }

    // MARK: - Storage Keys
    struct StorageKeys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasSeenTutorial = "hasSeenTutorial"
        static let healthKitAuthorized = "healthKitAuthorized"
        static let earnedCaloriesMode = "earnedCaloriesMode"
        static let hideDonationPopup = "hideDonationPopup"
        static let selectedAIProvider = "selected_ai_provider"
    }
}

// MARK: - Unit Conversion Helpers
extension Constants {
    /// Convert inches to centimetres
    static func inchesToCm(_ inches: Double) -> Double {
        inches * 2.54
    }

    /// Convert centimetres to inches
    static func cmToInches(_ cm: Double) -> Double {
        cm / 2.54
    }

    /// Convert pounds to kilograms
    static func lbsToKg(_ lbs: Double) -> Double {
        lbs * 0.453592
    }

    /// Convert kilograms to pounds
    static func kgToLbs(_ kg: Double) -> Double {
        kg / 0.453592
    }
}
