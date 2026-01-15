// TutorialManager.swift - Manages onboarding tutorial state
// Made by mpcode

import SwiftUI

// MARK: - Coach Mark Model
struct CoachMark: Identifiable {
    let id: String
    let title: String
    let message: String
    let tabIndex: Int?  // Which tab to highlight (nil for non-tab elements)
    let highlightRect: CGRect?  // Custom highlight area (optional)
    let position: CoachMarkPosition

    init(id: String, title: String, message: String, tabIndex: Int? = nil, highlightRect: CGRect? = nil, position: CoachMarkPosition = .below) {
        self.id = id
        self.title = title
        self.message = message
        self.tabIndex = tabIndex
        self.highlightRect = highlightRect
        self.position = position
    }
}

enum CoachMarkPosition {
    case above
    case below
    case left
    case right
}

// MARK: - Tutorial Manager
@Observable
class TutorialManager {
    static let shared = TutorialManager()

    var isShowingTutorial = false
    var currentCoachMarkIndex = 0
    var shouldStartTutorial = false

    // Coach marks sequence
    let coachMarks: [CoachMark] = [
        CoachMark(
            id: "dashboard",
            title: "Your Dashboard",
            message: "See your daily calories, macros, and nutrition at a glance. Swipe left on the calorie ring for vitamins!",
            tabIndex: 0,
            position: .below
        ),
        CoachMark(
            id: "addFood",
            title: "Add Food",
            message: "Log your meals here. Use AI to describe what you ate, scan barcodes, or add food manually.",
            tabIndex: 1,
            position: .above
        ),
        CoachMark(
            id: "products",
            title: "Your Products",
            message: "All scanned and saved products are stored here for quick access next time.",
            tabIndex: 2,
            position: .above
        ),
        CoachMark(
            id: "aiLogs",
            title: "AI Activity",
            message: "View all AI interactions and responses here. Great for debugging or reviewing estimates.",
            tabIndex: 3,
            position: .above
        ),
        CoachMark(
            id: "settings",
            title: "Settings",
            message: "Update your profile, goals, and AI preferences anytime. Configure your API keys here too!",
            tabIndex: 4,
            position: .above
        )
    ]

    var currentCoachMark: CoachMark? {
        guard currentCoachMarkIndex < coachMarks.count else { return nil }
        return coachMarks[currentCoachMarkIndex]
    }

    var progress: Double {
        guard !coachMarks.isEmpty else { return 0 }
        return Double(currentCoachMarkIndex + 1) / Double(coachMarks.count)
    }

    private init() {}

    func startTutorial() {
        currentCoachMarkIndex = 0
        isShowingTutorial = true
    }

    func nextStep() {
        if currentCoachMarkIndex < coachMarks.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentCoachMarkIndex += 1
            }
        } else {
            completeTutorial()
        }
    }

    func previousStep() {
        if currentCoachMarkIndex > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentCoachMarkIndex -= 1
            }
        }
    }

    func skipTutorial() {
        completeTutorial()
    }

    private func completeTutorial() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingTutorial = false
        }
        currentCoachMarkIndex = 0
        // Mark tutorial as seen
        UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
    }

    var hasSeenTutorial: Bool {
        UserDefaults.standard.bool(forKey: "hasSeenTutorial")
    }

    func resetTutorial() {
        UserDefaults.standard.set(false, forKey: "hasSeenTutorial")
        currentCoachMarkIndex = 0
    }
}
