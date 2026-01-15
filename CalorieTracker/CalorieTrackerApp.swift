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

        // Local storage for food data (CloudKit disabled due to container configuration issues)
        // Settings sync via iCloud Key-Value Store (CloudSettingsManager) - this works fine
        // TODO: Re-enable CloudKit once container association issue is resolved
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
