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

            Tab("Settings", systemImage: "gear", value: 3) {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self], inMemory: true)
}
