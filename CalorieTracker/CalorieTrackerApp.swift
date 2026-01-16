// CalorieTracker - iOS Calorie Tracking App
// Made by mpcode
// https://github.com/mp-c0de/CalorieTracker

import SwiftUI
import SwiftData

@main
struct CalorieTrackerApp: App {
    @State private var cloudSettings = CloudSettingsManager.shared
    @State private var tutorialManager = TutorialManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Product.self,
            FoodEntry.self,
            DailyLog.self,
            AIFoodTemplate.self,
            AILogEntry.self
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
                    ContentView(tutorialManager: tutorialManager)
                } else {
                    OnboardingView { showTutorial in
                        cloudSettings.hasCompletedOnboarding = true
                        if showTutorial {
                            tutorialManager.shouldStartTutorial = true
                        }
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
