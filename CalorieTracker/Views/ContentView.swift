// ContentView.swift - Main tab view
// Made by mpcode

import SwiftUI
import SwiftData
import TipKit

struct ContentView: View {
    @State private var selectedTab = 0

    // Observe tip version to force view recreation on reset
    private var tipVersion: Int { TutorialManager.shared.tipVersion }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: 0) {
                DashboardView()
                    .id("dashboard_\(tipVersion)")
            } label: {
                Label("Today", systemImage: "flame.fill")
            }

            Tab(value: 1) {
                AddFoodView()
                    .id("addfood_\(tipVersion)")
            } label: {
                Label("Add Food", systemImage: "plus.circle.fill")
            }

            Tab(value: 2) {
                ProductListView()
                    .id("products_\(tipVersion)")
            } label: {
                Label("Products", systemImage: "barcode.viewfinder")
            }

            Tab(value: 3) {
                ManualProductsView()
            } label: {
                Label("Manual", systemImage: "square.and.pencil")
            }

            Tab(value: 4) {
                AILogView()
            } label: {
                Label("AI Logs", systemImage: "doc.text.magnifyingglass")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self, AIFoodTemplate.self, AILogEntry.self], inMemory: true)
        .task {
            try? Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
        }
}
