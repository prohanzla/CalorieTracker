// CalorieTracker - iOS Calorie Tracking App
// Made by mpcode
// https://github.com/mp-c0de/CalorieTracker

import SwiftUI
import SwiftData

@main
struct CalorieTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Product.self,
            FoodEntry.self,
            DailyLog.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
