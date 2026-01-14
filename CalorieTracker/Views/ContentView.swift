// ContentView.swift - Main tab view
// Made by mpcode

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "flame.fill", value: 0) {
                DashboardView()
            }

            Tab("Add Food", systemImage: "plus.circle.fill", value: 1) {
                AddFoodView()
            }

            Tab("Products", systemImage: "barcode.viewfinder", value: 2) {
                ProductListView()
            }

            Tab("AI Logs", systemImage: "doc.text.magnifyingglass", value: 3) {
                AILogView()
            }

            Tab("Settings", systemImage: "gear", value: 4) {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self, AIFoodTemplate.self, AILogEntry.self], inMemory: true)
}
