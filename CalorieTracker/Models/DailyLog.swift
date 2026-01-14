// DailyLog.swift - SwiftData model for daily calorie tracking
// Made by mpcode

import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID
    var date: Date

    // Daily targets (customisable per user)
    var calorieTarget: Double
    var proteinTarget: Double
    var carbTarget: Double
    var fatTarget: Double

    @Relationship(deleteRule: .cascade, inverse: \FoodEntry.dailyLog)
    var entries: [FoodEntry]?

    // AI-analyzed vitamin values (optional - set when user requests analysis)
    var aiVitaminA: Double?
    var aiVitaminC: Double?
    var aiVitaminD: Double?
    var aiVitaminE: Double?
    var aiVitaminK: Double?
    var aiVitaminB1: Double?
    var aiVitaminB2: Double?
    var aiVitaminB3: Double?
    var aiVitaminB6: Double?
    var aiVitaminB12: Double?
    var aiFolate: Double?
    var aiCalcium: Double?
    var aiIron: Double?
    var aiZinc: Double?
    var aiMagnesium: Double?
    var aiPotassium: Double?
    var aiPhosphorus: Double?
    var aiSelenium: Double?
    var aiCopper: Double?
    var aiManganese: Double?
    var aiSodium: Double?
    var aiAnalysisDate: Date?

    var hasAIVitaminAnalysis: Bool {
        aiAnalysisDate != nil
    }

    init(
        date: Date = Date(),
        calorieTarget: Double = 2000,
        proteinTarget: Double = 50,
        carbTarget: Double = 250,
        fatTarget: Double = 65
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.carbTarget = carbTarget
        self.fatTarget = fatTarget
    }

    // Computed totals
    var totalCalories: Double {
        entries?.reduce(0) { $0 + $1.calories } ?? 0
    }

    var totalProtein: Double {
        entries?.reduce(0) { $0 + $1.protein } ?? 0
    }

    var totalCarbs: Double {
        entries?.reduce(0) { $0 + $1.carbohydrates } ?? 0
    }

    var totalFat: Double {
        entries?.reduce(0) { $0 + $1.fat } ?? 0
    }

    var totalSugar: Double {
        entries?.reduce(0) { $0 + $1.sugar } ?? 0
    }

    var totalFibre: Double {
        entries?.reduce(0) { $0 + $1.fibre } ?? 0
    }

    var totalSodium: Double {
        entries?.reduce(0) { $0 + $1.sodium } ?? 0
    }

    var caloriesRemaining: Double {
        calorieTarget - totalCalories
    }

    var calorieProgress: Double {
        min(totalCalories / calorieTarget, 1.0)
    }

    // Formatted date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}
