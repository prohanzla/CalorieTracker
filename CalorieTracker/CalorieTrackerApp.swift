// CalorieTracker - iOS Calorie Tracking App
// Made by mpcode
// https://github.com/mp-c0de/CalorieTracker

import SwiftUI
import SwiftData
import TipKit

@main
struct CalorieTrackerApp: App {
    @State private var cloudSettings = CloudSettingsManager.shared

    init() {
        // Configure TipKit for tutorial tips
        TutorialManager.configureTips()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Product.self,
            FoodEntry.self,
            DailyLog.self,
            AIFoodTemplate.self,
            AILogEntry.self,
            Supplement.self,
            SupplementEntry.self
        ])

        // Enable iCloud CloudKit sync for automatic backup across devices
        // All models have default values for non-optional properties (CloudKit requirement)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Fallback to local-only storage if CloudKit fails
            print("CloudKit sync failed, falling back to local storage: \(error)")
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if cloudSettings.hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingView {
                        cloudSettings.hasCompletedOnboarding = true
                    }
                }
            }
            .onAppear {
                // Migrate existing local settings to iCloud on first launch
                cloudSettings.migrateFromLocalStorage()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
