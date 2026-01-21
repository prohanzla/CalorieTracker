// HealthKitManager.swift - Manages HealthKit data access for activity tracking
// Made by mpcode

import Foundation
import HealthKit
import Observation

@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    // MARK: - Published Data
    var todaySteps: Int = 0
    var todayActiveCalories: Int = 0  // Active energy burned from HealthKit
    var todayWorkoutCalories: Int = 0 // Calories specifically from workouts
    var todayTotalCalories: Int = 0   // Basal + Active energy
    var todayExerciseMinutes: Int = 0 // Exercise minutes from workouts
    var isAuthorized: Bool = false  // Observable property for UI updates
    var isConnecting: Bool = false  // Shows loading state
    var authorizationStatus: String = "Not Requested"

    // MARK: - User Profile Data (from HealthKit)
    var userBiologicalSex: String? = nil  // "Male", "Female", or nil
    var userDateOfBirth: Date? = nil
    var userHeightCm: Double? = nil
    var userWeightKg: Double? = nil

    // Manual override for earned calories (stored property for SwiftUI observation)
    private var _manualEarnedCalories: Int = 0

    var manualEarnedCalories: Int {
        get { _manualEarnedCalories }
        set {
            _manualEarnedCalories = newValue
            UserDefaults.standard.set(newValue, forKey: "manualEarnedCalories_\(todayDateKey)")
        }
    }

    // Date key for storing per-day manual calories
    private var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // Earned calories mode: 0 = workouts only (recommended), 1 = active, 2 = total
    private var _earnedCaloriesMode: Int = 0

    var earnedCaloriesMode: Int {
        get { _earnedCaloriesMode }
        set {
            _earnedCaloriesMode = newValue
            UserDefaults.standard.set(newValue, forKey: "earnedCaloriesMode")
        }
    }

    // Base earned from HealthKit based on mode
    var healthKitEarnedCalories: Int {
        switch earnedCaloriesMode {
        case 0: return todayWorkoutCalories  // Only gym/workout calories (recommended)
        case 1:
            // All active energy - ensure workouts are included
            // Some devices record workouts separately from activeEnergyBurned
            // If active < workouts, workouts clearly aren't included, so add them
            if todayActiveCalories < todayWorkoutCalories {
                return todayActiveCalories + todayWorkoutCalories
            }
            return todayActiveCalories
        case 2:
            // Total burned (active + basal) - ensure workouts included
            // todayTotalCalories = active + basal, so basal = total - active
            if todayActiveCalories < todayWorkoutCalories {
                let basal = todayTotalCalories - todayActiveCalories
                return todayActiveCalories + todayWorkoutCalories + basal
            }
            return todayTotalCalories
        default: return todayWorkoutCalories
        }
    }

    // Total earned calories = HealthKit (active or total) + manual
    var totalEarnedCalories: Int {
        healthKitEarnedCalories + _manualEarnedCalories
    }

    // Load manual calories for today from UserDefaults
    private func loadManualCalories() {
        _manualEarnedCalories = UserDefaults.standard.integer(forKey: "manualEarnedCalories_\(todayDateKey)")
    }

    // MARK: - Availability
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private init() {
        // Load saved settings
        loadManualCalories()
        _earnedCaloriesMode = UserDefaults.standard.integer(forKey: "earnedCaloriesMode")

        // Load saved state and verify on init
        if UserDefaults.standard.bool(forKey: "healthKitAuthorized") {
            isAuthorized = true
            authorizationStatus = "Authorized"
            Task {
                await verifyAuthorizationByFetching()
            }
        }
    }

    // MARK: - Disconnect
    func disconnect() {
        isAuthorized = false
        authorizationStatus = "Not Requested"
        todaySteps = 0
        todayActiveCalories = 0
        todayTotalCalories = 0
        UserDefaults.standard.set(false, forKey: "healthKitAuthorized")
    }

    // MARK: - Authorization
    @MainActor
    func requestAuthorization() async {
        guard isHealthKitAvailable else {
            authorizationStatus = "HealthKit not available"
            return
        }

        // Show connecting state
        isConnecting = true

        // Types we want to read - activity data
        var typesToRead: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKObjectType.workoutType(),
            // Body measurements
            HKQuantityType(.height),
            HKQuantityType(.bodyMass)
        ]

        // Add characteristic types (date of birth, biological sex)
        if let dobType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            typesToRead.insert(dobType)
        }
        if let sexType = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            typesToRead.insert(sexType)
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            // Save to UserDefaults for persistence
            UserDefaults.standard.set(true, forKey: "healthKitAuthorized")
            isAuthorized = true
            authorizationStatus = "Authorized"
            isConnecting = false
            // Fetch initial data and user profile
            await fetchTodayData()
            await fetchUserProfile()
        } catch {
            isConnecting = false
            isAuthorized = false
            authorizationStatus = "Authorization failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Check Current Authorization Status
    func checkAuthorizationStatus() {
        guard isHealthKitAvailable else {
            authorizationStatus = "HealthKit not available"
            return
        }

        // If we have saved that user connected, verify by fetching
        if UserDefaults.standard.bool(forKey: "healthKitAuthorized") {
            authorizationStatus = "Authorized"
            Task {
                await verifyAuthorizationByFetching()
            }
        } else {
            authorizationStatus = "Not Requested"
        }
    }

    // MARK: - Verify Authorization by Actually Fetching Data
    func verifyAuthorizationByFetching() async {
        guard isHealthKitAvailable else { return }

        // Try to fetch steps - if we get data or zero (not an error), we're authorized
        let stepType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .strictStartDate
        )

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [weak self] _, result, error in
                Task { @MainActor in
                    // HealthKit queries can return nil result with no error if no data exists
                    // This is still valid authorization - user just has no steps yet today
                    // Only treat explicit authorization errors as unauthorized
                    if let error = error as? HKError, error.code == .errorAuthorizationDenied {
                        self?.isAuthorized = false
                        self?.authorizationStatus = "Not Authorized"
                        UserDefaults.standard.set(false, forKey: "healthKitAuthorized")
                    } else {
                        // No error or non-authorization error means we're still authorized
                        self?.isAuthorized = true
                        self?.authorizationStatus = "Authorized"
                        // Fetch all data
                        await self?.fetchTodayData()
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Today's Data
    func fetchTodayData() async {
        guard isHealthKitAvailable else { return }

        async let steps = fetchTodaySteps()
        async let activeCalories = fetchTodayActiveCalories()
        async let basalCalories = fetchTodayBasalCalories()
        async let exerciseMinutes = fetchTodayExerciseMinutes()
        async let workoutCalories = fetchTodayWorkoutCalories()

        let (stepsResult, activeResult, basalResult, exerciseResult, workoutResult) = await (steps, activeCalories, basalCalories, exerciseMinutes, workoutCalories)

        await MainActor.run {
            todaySteps = stepsResult
            todayActiveCalories = activeResult
            todayTotalCalories = activeResult + basalResult
            todayExerciseMinutes = exerciseResult
            todayWorkoutCalories = workoutResult
        }
    }

    // MARK: - Fetch Steps
    private func fetchTodaySteps() async -> Int {
        let stepType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Active Calories
    private func fetchTodayActiveCalories() async -> Int {
        let energyType = HKQuantityType(.activeEnergyBurned)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                let calories = Int(sum.doubleValue(for: HKUnit.kilocalorie()))
                continuation.resume(returning: calories)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Basal Calories
    private func fetchTodayBasalCalories() async -> Int {
        let energyType = HKQuantityType(.basalEnergyBurned)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                let calories = Int(sum.doubleValue(for: HKUnit.kilocalorie()))
                continuation.resume(returning: calories)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Exercise Minutes
    private func fetchTodayExerciseMinutes() async -> Int {
        let exerciseType = HKQuantityType(.appleExerciseTime)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: exerciseType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                let minutes = Int(sum.doubleValue(for: HKUnit.minute()))
                continuation.resume(returning: minutes)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Workout Calories
    private func fetchTodayWorkoutCalories() async -> Int {
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: 0)
                    return
                }

                // Sum up total energy burned from all workouts
                let totalCalories = workouts.reduce(0.0) { total, workout in
                    // Use new iOS 16+ API (statisticsForType) instead of deprecated totalEnergyBurned
                    let energyType = HKQuantityType(.activeEnergyBurned)
                    let energy = workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                    return total + energy
                }
                continuation.resume(returning: Int(totalCalories))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Calculate Net Calories
    /// Returns the adjusted calorie target including earned calories (HealthKit + manual)
    func netCalorieTarget(baseTarget: Double) -> Double {
        // Add earned calories to base target (you "earn" more food calories through activity)
        // Uses totalEarnedCalories which includes both HealthKit active calories and manual additions
        return baseTarget + Double(totalEarnedCalories)
    }

    /// Returns how many calories are remaining after eating and exercise
    func netCaloriesRemaining(consumed: Double, baseTarget: Double) -> Double {
        let adjustedTarget = netCalorieTarget(baseTarget: baseTarget)
        return adjustedTarget - consumed
    }

    // MARK: - Manual Calories Management
    /// Add manual earned calories for today
    func addManualCalories(_ calories: Int) {
        manualEarnedCalories += calories
    }

    /// Set manual earned calories for today (replaces existing value)
    func setManualCalories(_ calories: Int) {
        manualEarnedCalories = calories
    }

    /// Clear manual earned calories for today
    func clearManualCalories() {
        manualEarnedCalories = 0
    }

    // MARK: - Exercise-Adjusted Nutrient Limits
    /// Structure holding adjusted daily limits based on exercise
    struct ExerciseAdjustedLimits {
        let sodium: Double        // mg (base: 2300mg)
        let potassium: Double     // mg (base: 4700mg)
        let carbs: Double         // g (base: ~300g for men, ~225g for women)
        let sugar: Double         // g (added sugar base: 36g men, 25g women)
        let protein: Double       // g (base: 56g men, 46g women)
        let magnesium: Double     // mg (base: 420mg)

        // How much was added due to exercise
        let sodiumBonus: Double
        let potassiumBonus: Double
        let carbsBonus: Double
        let sugarBonus: Double
        let proteinBonus: Double
        let magnesiumBonus: Double
    }

    /// Calculate exercise-adjusted nutrient limits based on workout activity
    /// - Parameters:
    ///   - baseSodium: Base daily sodium limit (default 2300mg)
    ///   - basePotassium: Base daily potassium target (default 4700mg)
    ///   - baseCarbs: Base daily carbs target
    ///   - baseSugar: Base daily added sugar limit (36g men, 25g women)
    ///   - baseProtein: Base daily protein target
    ///   - baseMagnesium: Base daily magnesium target (default 420mg)
    func exerciseAdjustedLimits(
        baseSodium: Double = 2300,
        basePotassium: Double = 4700,
        baseCarbs: Double = 300,
        baseSugar: Double = 36,
        baseProtein: Double = 56,
        baseMagnesium: Double = 420
    ) -> ExerciseAdjustedLimits {
        // Calculate adjustments based on workout calories burned
        // These are science-based approximations for nutrient losses during exercise

        let workoutCals = Double(todayWorkoutCalories)
        let exerciseMins = Double(todayExerciseMinutes)

        // Sodium: Lose ~500-1000mg per hour of moderate-intense exercise
        // Approximation: +500mg per 30 minutes of exercise
        let sodiumBonus = (exerciseMins / 30.0) * 500.0

        // Potassium: Lose through sweat, ~200-400mg per hour
        // Approximation: +300mg per 30 minutes of exercise
        let potassiumBonus = (exerciseMins / 30.0) * 300.0

        // Carbs: Need for glycogen replenishment
        // Approximation: +30g carbs per 500 calories burned
        let carbsBonus = (workoutCals / 500.0) * 30.0

        // Sugar tolerance increases post-workout (for quick glycogen replenishment)
        // Approximation: +10g per 500 calories burned (natural sugars are fine post-workout)
        let sugarBonus = (workoutCals / 500.0) * 10.0

        // Protein: Need for muscle repair
        // Approximation: +10g per 500 calories burned from strength/cardio
        let proteinBonus = (workoutCals / 500.0) * 10.0

        // Magnesium: Lost through sweat, important for muscle function
        // Approximation: +50mg per 30 minutes of exercise
        let magnesiumBonus = (exerciseMins / 30.0) * 50.0

        return ExerciseAdjustedLimits(
            sodium: baseSodium + sodiumBonus,
            potassium: basePotassium + potassiumBonus,
            carbs: baseCarbs + carbsBonus,
            sugar: baseSugar + sugarBonus,
            protein: baseProtein + proteinBonus,
            magnesium: baseMagnesium + magnesiumBonus,
            sodiumBonus: sodiumBonus,
            potassiumBonus: potassiumBonus,
            carbsBonus: carbsBonus,
            sugarBonus: sugarBonus,
            proteinBonus: proteinBonus,
            magnesiumBonus: magnesiumBonus
        )
    }

    /// Quick access to adjusted sodium limit
    var adjustedSodiumLimit: Double {
        exerciseAdjustedLimits().sodium
    }

    /// Quick access to adjusted sugar limit (added sugars)
    var adjustedSugarLimit: Double {
        exerciseAdjustedLimits().sugar
    }

    /// Quick access to adjusted carbs target
    func adjustedCarbsTarget(base: Double) -> Double {
        exerciseAdjustedLimits(baseCarbs: base).carbs
    }

    /// Quick access to adjusted protein target
    func adjustedProteinTarget(base: Double) -> Double {
        exerciseAdjustedLimits(baseProtein: base).protein
    }

    // MARK: - Fetch User Profile Data
    /// Fetches user characteristics and body measurements from HealthKit
    @MainActor
    func fetchUserProfile() async {
        guard isHealthKitAvailable else { return }

        // Fetch biological sex
        do {
            let biologicalSex = try healthStore.biologicalSex()
            switch biologicalSex.biologicalSex {
            case .male:
                userBiologicalSex = "Male"
            case .female:
                userBiologicalSex = "Female"
            case .other:
                userBiologicalSex = nil
            case .notSet:
                userBiologicalSex = nil
            @unknown default:
                userBiologicalSex = nil
            }
        } catch {
            userBiologicalSex = nil
        }

        // Fetch date of birth
        do {
            let dobComponents = try healthStore.dateOfBirthComponents()
            userDateOfBirth = Calendar.current.date(from: dobComponents)
        } catch {
            userDateOfBirth = nil
        }

        // Fetch latest height
        userHeightCm = await fetchLatestHeight()

        // Fetch latest weight
        userWeightKg = await fetchLatestWeight()
    }

    /// Fetches the most recent height measurement from HealthKit
    private func fetchLatestHeight() async -> Double? {
        let heightType = HKQuantityType(.height)

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: heightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let heightInMeters = sample.quantity.doubleValue(for: HKUnit.meter())
                let heightInCm = heightInMeters * 100
                continuation.resume(returning: heightInCm)
            }
            healthStore.execute(query)
        }
    }

    /// Fetches the most recent weight measurement from HealthKit
    private func fetchLatestWeight() async -> Double? {
        let weightType = HKQuantityType(.bodyMass)

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                continuation.resume(returning: weightInKg)
            }
            healthStore.execute(query)
        }
    }

    /// Syncs user profile data from HealthKit to CloudSettingsManager
    /// Only updates settings that are currently empty/zero
    func syncUserProfileToSettings() {
        let cloudSettings = CloudSettingsManager.shared

        // Only update if current setting is empty
        if let sex = userBiologicalSex, cloudSettings.userGender.isEmpty {
            cloudSettings.userGender = sex
        }

        if let dob = userDateOfBirth, cloudSettings.userDateOfBirth == 0 {
            cloudSettings.userDateOfBirth = dob.timeIntervalSince1970
        }

        if let height = userHeightCm, height > 0, cloudSettings.userHeightCm == 0 {
            cloudSettings.userHeightCm = height
        }

        if let weight = userWeightKg, weight > 0, cloudSettings.userWeightKg == 0 {
            cloudSettings.userWeightKg = weight
        }
    }

    /// Force syncs all available user profile data from HealthKit to CloudSettingsManager
    /// Overwrites existing settings with HealthKit data
    func forceSyncUserProfileToSettings() {
        let cloudSettings = CloudSettingsManager.shared

        if let sex = userBiologicalSex {
            cloudSettings.userGender = sex
        }

        if let dob = userDateOfBirth {
            cloudSettings.userDateOfBirth = dob.timeIntervalSince1970
        }

        if let height = userHeightCm, height > 0 {
            cloudSettings.userHeightCm = height
        }

        if let weight = userWeightKg, weight > 0 {
            cloudSettings.userWeightKg = weight
        }
    }
}
