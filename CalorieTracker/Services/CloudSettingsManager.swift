// CloudSettingsManager.swift - iCloud Key-Value sync for user settings
// Made by mpcode

import Foundation
import Combine

// MARK: - Notification Extension
extension Notification.Name {
    static let cloudSettingsDidChange = Notification.Name("cloudSettingsDidChange")
}

/// Manages user settings synchronisation via iCloud Key-Value Store
/// Settings automatically sync across all devices signed into the same iCloud account
@Observable
final class CloudSettingsManager {
    static let shared = CloudSettingsManager()

    private let store = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Settings Keys
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let userGender = "userGender"
        static let userDateOfBirth = "userDateOfBirth"
        static let userHeightCm = "userHeightCm"
        static let userWeightKg = "userWeightKg"
        static let unitSystem = "unitSystem"
        static let dailyCalorieTarget = "dailyCalorieTarget"
        static let dailyProteinTarget = "dailyProteinTarget"
        static let dailyCarbTarget = "dailyCarbTarget"
        static let dailyFatTarget = "dailyFatTarget"
        static let selectedAIProvider = "selectedAIProvider"
        static let openAIKey = "openAIKey"
        static let claudeKey = "claudeKey"
        static let geminiKey = "geminiKey"
        static let hasSeenTutorial = "hasSeenTutorial"
    }

    // MARK: - Cached Properties (for SwiftUI observation)
    // These stored properties trigger SwiftUI updates while syncing to iCloud
    private var _hasCompletedOnboarding: Bool = false
    private var _userGender: String = ""
    private var _userDateOfBirth: Double = 0
    private var _userHeightCm: Double = 0
    private var _userWeightKg: Double = 0
    private var _unitSystem: String = "metric"
    private var _dailyCalorieTarget: Double = 2000.0
    private var _dailyProteinTarget: Double = 50.0
    private var _dailyCarbTarget: Double = 250.0
    private var _dailyFatTarget: Double = 65.0
    private var _selectedAIProvider: String = "openai"
    private var _openAIKey: String = ""
    private var _claudeKey: String = ""
    private var _geminiKey: String = ""
    private var _hasSeenTutorial: Bool = false

    // MARK: - Observable Properties
    var hasCompletedOnboarding: Bool {
        get { _hasCompletedOnboarding }
        set {
            _hasCompletedOnboarding = newValue
            store.set(newValue, forKey: Keys.hasCompletedOnboarding)
            synchronize()
        }
    }

    var userGender: String {
        get { _userGender }
        set {
            _userGender = newValue
            store.set(newValue, forKey: Keys.userGender)
            synchronize()
        }
    }

    var userDateOfBirth: Double {
        get { _userDateOfBirth }
        set {
            _userDateOfBirth = newValue
            store.set(newValue, forKey: Keys.userDateOfBirth)
            synchronize()
        }
    }

    var userHeightCm: Double {
        get { _userHeightCm }
        set {
            _userHeightCm = newValue
            store.set(newValue, forKey: Keys.userHeightCm)
            synchronize()
        }
    }

    var userWeightKg: Double {
        get { _userWeightKg }
        set {
            _userWeightKg = newValue
            store.set(newValue, forKey: Keys.userWeightKg)
            synchronize()
        }
    }

    var unitSystem: String {
        get { _unitSystem }
        set {
            _unitSystem = newValue
            store.set(newValue, forKey: Keys.unitSystem)
            synchronize()
        }
    }

    var dailyCalorieTarget: Double {
        get { _dailyCalorieTarget }
        set {
            _dailyCalorieTarget = newValue
            store.set(newValue, forKey: Keys.dailyCalorieTarget)
            synchronize()
        }
    }

    var dailyProteinTarget: Double {
        get { _dailyProteinTarget }
        set {
            _dailyProteinTarget = newValue
            store.set(newValue, forKey: Keys.dailyProteinTarget)
            synchronize()
        }
    }

    var dailyCarbTarget: Double {
        get { _dailyCarbTarget }
        set {
            _dailyCarbTarget = newValue
            store.set(newValue, forKey: Keys.dailyCarbTarget)
            synchronize()
        }
    }

    var dailyFatTarget: Double {
        get { _dailyFatTarget }
        set {
            _dailyFatTarget = newValue
            store.set(newValue, forKey: Keys.dailyFatTarget)
            synchronize()
        }
    }

    var selectedAIProvider: String {
        get { _selectedAIProvider }
        set {
            _selectedAIProvider = newValue
            store.set(newValue, forKey: Keys.selectedAIProvider)
            synchronize()
        }
    }

    var openAIKey: String {
        get { _openAIKey }
        set {
            _openAIKey = newValue
            store.set(newValue, forKey: Keys.openAIKey)
            synchronize()
        }
    }

    var claudeKey: String {
        get { _claudeKey }
        set {
            _claudeKey = newValue
            store.set(newValue, forKey: Keys.claudeKey)
            synchronize()
        }
    }

    var geminiKey: String {
        get { _geminiKey }
        set {
            _geminiKey = newValue
            store.set(newValue, forKey: Keys.geminiKey)
            synchronize()
        }
    }

    var hasSeenTutorial: Bool {
        get { _hasSeenTutorial }
        set {
            _hasSeenTutorial = newValue
            store.set(newValue, forKey: Keys.hasSeenTutorial)
            synchronize()
        }
    }

    // MARK: - Initialisation
    private init() {
        // Start syncing
        store.synchronize()

        // Load initial values from store
        loadFromStore()

        // Listen for external changes (from other devices)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }

    /// Load all values from iCloud store into cached properties
    private func loadFromStore() {
        _hasCompletedOnboarding = store.bool(forKey: Keys.hasCompletedOnboarding)
        _userGender = store.string(forKey: Keys.userGender) ?? ""
        _userDateOfBirth = store.double(forKey: Keys.userDateOfBirth)
        _userHeightCm = store.double(forKey: Keys.userHeightCm)
        _userWeightKg = store.double(forKey: Keys.userWeightKg)
        _unitSystem = store.string(forKey: Keys.unitSystem) ?? "metric"

        let calories = store.double(forKey: Keys.dailyCalorieTarget)
        _dailyCalorieTarget = calories > 0 ? calories : 2000.0

        let protein = store.double(forKey: Keys.dailyProteinTarget)
        _dailyProteinTarget = protein > 0 ? protein : 50.0

        let carbs = store.double(forKey: Keys.dailyCarbTarget)
        _dailyCarbTarget = carbs > 0 ? carbs : 250.0

        let fat = store.double(forKey: Keys.dailyFatTarget)
        _dailyFatTarget = fat > 0 ? fat : 65.0

        _selectedAIProvider = store.string(forKey: Keys.selectedAIProvider) ?? "openai"
        _openAIKey = store.string(forKey: Keys.openAIKey) ?? ""
        _claudeKey = store.string(forKey: Keys.claudeKey) ?? ""
        _geminiKey = store.string(forKey: Keys.geminiKey) ?? ""
        _hasSeenTutorial = store.bool(forKey: Keys.hasSeenTutorial)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Sync Methods
    private func synchronize() {
        store.synchronize()
    }

    @objc private func storeDidChange(_ notification: Notification) {
        // Handle changes from other devices - reload cached values
        DispatchQueue.main.async { [weak self] in
            self?.loadFromStore()
            NotificationCenter.default.post(name: .cloudSettingsDidChange, object: nil)
        }
    }

    // MARK: - Migration from AppStorage
    /// Migrates existing local settings to iCloud
    /// Call this once on app launch to preserve existing user data
    func migrateFromLocalStorage() {
        let defaults = UserDefaults.standard

        // Only migrate if not already done
        if !store.bool(forKey: "migrationCompleted") {
            // Migrate each setting if it exists locally but not in cloud
            if defaults.bool(forKey: Keys.hasCompletedOnboarding) && !store.bool(forKey: Keys.hasCompletedOnboarding) {
                hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
            }

            if let gender = defaults.string(forKey: Keys.userGender), !gender.isEmpty, userGender.isEmpty {
                userGender = gender
            }

            let dob = defaults.double(forKey: Keys.userDateOfBirth)
            if dob > 0 && userDateOfBirth == 0 {
                userDateOfBirth = dob
            }

            let height = defaults.double(forKey: Keys.userHeightCm)
            if height > 0 && userHeightCm == 0 {
                userHeightCm = height
            }

            let weight = defaults.double(forKey: Keys.userWeightKg)
            if weight > 0 && userWeightKg == 0 {
                userWeightKg = weight
            }

            if let unit = defaults.string(forKey: Keys.unitSystem), !unit.isEmpty {
                unitSystem = unit
            }

            let calories = defaults.double(forKey: Keys.dailyCalorieTarget)
            if calories > 0 {
                dailyCalorieTarget = calories
            }

            let protein = defaults.double(forKey: Keys.dailyProteinTarget)
            if protein > 0 {
                dailyProteinTarget = protein
            }

            let carbs = defaults.double(forKey: Keys.dailyCarbTarget)
            if carbs > 0 {
                dailyCarbTarget = carbs
            }

            let fat = defaults.double(forKey: Keys.dailyFatTarget)
            if fat > 0 {
                dailyFatTarget = fat
            }

            if let provider = defaults.string(forKey: Keys.selectedAIProvider), !provider.isEmpty {
                selectedAIProvider = provider
            }

            if let key = defaults.string(forKey: Keys.openAIKey), !key.isEmpty {
                openAIKey = key
            }

            if let key = defaults.string(forKey: Keys.claudeKey), !key.isEmpty {
                claudeKey = key
            }

            if let key = defaults.string(forKey: Keys.geminiKey), !key.isEmpty {
                geminiKey = key
            }

            if defaults.bool(forKey: Keys.hasSeenTutorial) {
                hasSeenTutorial = true
            }

            // Mark migration as complete
            store.set(true, forKey: "migrationCompleted")
            synchronize()
        }
    }

    // MARK: - Reset
    /// Resets onboarding state (for testing)
    func resetOnboarding() {
        hasCompletedOnboarding = false
        hasSeenTutorial = false
    }

    /// Clears all cloud settings (use with caution)
    func clearAllSettings() {
        let keys = [
            Keys.hasCompletedOnboarding, Keys.userGender, Keys.userDateOfBirth,
            Keys.userHeightCm, Keys.userWeightKg, Keys.unitSystem,
            Keys.dailyCalorieTarget, Keys.dailyProteinTarget, Keys.dailyCarbTarget,
            Keys.dailyFatTarget, Keys.selectedAIProvider, Keys.openAIKey,
            Keys.claudeKey, Keys.geminiKey, Keys.hasSeenTutorial, "migrationCompleted"
        ]

        for key in keys {
            store.removeObject(forKey: key)
        }
        synchronize()

        // Reset cached properties to defaults
        _hasCompletedOnboarding = false
        _userGender = ""
        _userDateOfBirth = 0
        _userHeightCm = 0
        _userWeightKg = 0
        _unitSystem = "metric"
        _dailyCalorieTarget = 2000.0
        _dailyProteinTarget = 50.0
        _dailyCarbTarget = 250.0
        _dailyFatTarget = 65.0
        _selectedAIProvider = "openai"
        _openAIKey = ""
        _claudeKey = ""
        _geminiKey = ""
        _hasSeenTutorial = false
    }

    // MARK: - Calorie & Macro Calculations

    /// User's age calculated from date of birth
    var userAge: Int? {
        guard userDateOfBirth > 0 else { return nil }
        let dob = Date(timeIntervalSince1970: userDateOfBirth)
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    /// Calculate recommended daily calories using Mifflin-St Jeor equation
    /// Returns nil if profile data is incomplete
    func calculateRecommendedCalories() -> Int? {
        guard userHeightCm > 0,
              userWeightKg > 0,
              let age = userAge,
              !userGender.isEmpty else { return nil }

        // Mifflin-St Jeor Equation for BMR
        let bmr: Double
        if userGender == "Male" {
            bmr = 10 * userWeightKg + 6.25 * userHeightCm - 5 * Double(age) + 5
        } else {
            bmr = 10 * userWeightKg + 6.25 * userHeightCm - 5 * Double(age) - 161
        }

        // Use sedentary multiplier (1.2) as baseline TDEE
        let tdee = bmr * 1.2
        return Int(tdee.rounded())
    }

    /// Calculate recommended macros based on calorie target
    /// Standard split: 30% protein, 40% carbs, 30% fat
    func calculateRecommendedMacros(forCalories calories: Double) -> (protein: Double, carbs: Double, fat: Double) {
        let proteinCalories = calories * 0.30
        let carbCalories = calories * 0.40
        let fatCalories = calories * 0.30

        // Convert to grams (4 cal/g protein, 4 cal/g carbs, 9 cal/g fat)
        let protein = round(proteinCalories / 4)
        let carbs = round(carbCalories / 4)
        let fat = round(fatCalories / 9)

        return (protein, carbs, fat)
    }

    /// Calculate and apply recommended calories and macros to settings
    func applyRecommendedTargets() {
        guard let calories = calculateRecommendedCalories() else { return }

        // Round to nearest 50
        let roundedCalories = Double(Int(round(Double(calories) / 50) * 50))
        dailyCalorieTarget = roundedCalories

        let macros = calculateRecommendedMacros(forCalories: roundedCalories)
        dailyProteinTarget = macros.protein
        dailyCarbTarget = macros.carbs
        dailyFatTarget = macros.fat
    }
}
