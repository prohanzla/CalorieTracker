// ContentView.swift - Main tab view
// Made by mpcode

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    var tutorialManager: TutorialManager = TutorialManager.shared

    // Tab bar height for coach mark positioning
    private let tabBarHeight: CGFloat = 83

    var body: some View {
        ZStack {
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

                Tab("Manual", systemImage: "square.and.pencil", value: 3) {
                    ManualProductsView()
                }

                Tab("AI Logs", systemImage: "doc.text.magnifyingglass", value: 4) {
                    AILogView()
                }
            }
            .onChange(of: tutorialManager.currentCoachMarkIndex) { _, newIndex in
                // Auto-navigate to the tab being highlighted
                if tutorialManager.isShowingTutorial,
                   let coachMark = tutorialManager.currentCoachMark,
                   let tabIndex = coachMark.tabIndex {
                    withAnimation {
                        selectedTab = tabIndex
                    }
                }
            }

            // Tutorial overlay
            if tutorialManager.isShowingTutorial, let coachMark = tutorialManager.currentCoachMark {
                CoachMarkOverlay(
                    coachMark: coachMark,
                    currentStep: tutorialManager.currentCoachMarkIndex + 1,
                    totalSteps: tutorialManager.coachMarks.count,
                    tabBarHeight: tabBarHeight,
                    onNext: { tutorialManager.nextStep() },
                    onSkip: { tutorialManager.skipTutorial() }
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: tutorialManager.isShowingTutorial)
            }
        }
        .onAppear {
            // Start tutorial if requested from onboarding
            if tutorialManager.shouldStartTutorial {
                tutorialManager.shouldStartTutorial = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tutorialManager.startTutorial()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self, AIFoodTemplate.self, AILogEntry.self], inMemory: true)
}
