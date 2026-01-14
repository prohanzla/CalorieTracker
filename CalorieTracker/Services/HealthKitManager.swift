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
    var todayActiveCalories: Int = 0  // Active energy burned
    var todayTotalCalories: Int = 0   // Basal + Active energy
    var isAuthorized: Bool = false  // Observable property for UI updates
    var isConnecting: Bool = false  // Shows loading state
    var authorizationStatus: String = "Not Requested"

    // MARK: - Availability
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private init() {
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

        // Types we want to read
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            // Save to UserDefaults for persistence
            UserDefaults.standard.set(true, forKey: "healthKitAuthorized")
            isAuthorized = true
            authorizationStatus = "Authorized"
            isConnecting = false
            // Fetch initial data
            await fetchTodayData()
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
                    if error == nil {
                        // Successfully queried - we have authorization
                        self?.isAuthorized = true
                        self?.authorizationStatus = "Authorized"
                        // Fetch all data
                        await self?.fetchTodayData()
                    } else {
                        // Error means no authorization or user revoked it
                        self?.isAuthorized = false
                        self?.authorizationStatus = "Not Authorized"
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

        let (stepsResult, activeResult, basalResult) = await (steps, activeCalories, basalCalories)

        await MainActor.run {
            todaySteps = stepsResult
            todayActiveCalories = activeResult
            todayTotalCalories = activeResult + basalResult
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

    // MARK: - Calculate Net Calories
    /// Returns the adjusted calorie target after subtracting burned calories
    func netCalorieTarget(baseTarget: Double) -> Double {
        // Subtract active calories from base target (you "earn" more food calories)
        // Only subtract active, not basal (basal is already accounted for in TDEE)
        return baseTarget + Double(todayActiveCalories)
    }

    /// Returns how many calories are remaining after eating and exercise
    func netCaloriesRemaining(consumed: Double, baseTarget: Double) -> Double {
        let adjustedTarget = netCalorieTarget(baseTarget: baseTarget)
        return adjustedTarget - consumed
    }
}
