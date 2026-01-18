// TutorialManager.swift - Manages tutorial tips using TipKit
// Made by mpcode

import SwiftUI
import TipKit

// MARK: - Tutorial Manager & Tips Store

@Observable
class TutorialManager {
    static let shared = TutorialManager()

    /// Current tip version - changes on reset to make tips appear as "new"
    private(set) var tipVersion: Int

    private static let tipVersionKey = "TutorialTipVersion"

    private init() {
        self.tipVersion = UserDefaults.standard.integer(forKey: TutorialManager.tipVersionKey)
    }

    /// Configure TipKit - call this on app launch (only once!)
    static func configureTips() {
        do {
            try Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
        } catch {
            print("TipKit configuration: \(error)")
        }
    }

    /// Reset all tips - increments version so tips are treated as new
    func resetAllTips() {
        tipVersion += 1
        UserDefaults.standard.set(tipVersion, forKey: TutorialManager.tipVersionKey)
        // New version = new tip IDs = tips appear as "unseen"
        // Don't use showAllTipsForTesting() as it overrides dismissal behavior
    }

    /// Hide all tips (for users who don't want them)
    func hideAllTips() {
        Tips.hideAllTipsForTesting()
    }
}

// MARK: - Defined Tips
// Tips with dynamic IDs based on version - reset changes ID so TipKit treats as new

struct SettingsTip: Tip {
    private let version = TutorialManager.shared.tipVersion
    var id: String { "settings_tip_v\(version)" }
    var title: Text { Text("Settings & Profile") }
    var message: Text? { Text("Tap here to set your calorie goals and preferences.") }
    var image: Image? { Image(systemName: "gear") }
}

struct CalorieRingTip: Tip {
    private let version = TutorialManager.shared.tipVersion
    var id: String { "calorie_ring_tip_v\(version)" }
    var title: Text { Text("Your Daily Progress") }
    var message: Text? { Text("Track your calories here - the ring fills as you log food.") }
    var image: Image? { Image(systemName: "circle.dotted") }
}

struct SwipeVitaminsTip: Tip {
    private let version = TutorialManager.shared.tipVersion
    var id: String { "swipe_vitamins_tip_v\(version)" }
    var title: Text { Text("Swipe for More") }
    var message: Text? { Text("Swipe left to see vitamins and history.") }
    var image: Image? { Image(systemName: "hand.draw") }
}

struct AIQuickAddTip: Tip {
    private let version = TutorialManager.shared.tipVersion
    var id: String { "ai_quick_add_tip_v\(version)" }
    var title: Text { Text("AI Quick Add") }
    var message: Text? { Text("Type what you ate - AI estimates calories!") }
    var image: Image? { Image(systemName: "sparkles") }
}

struct ScanBarcodeTip: Tip {
    private let version = TutorialManager.shared.tipVersion
    var id: String { "scan_barcode_tip_v\(version)" }
    var title: Text { Text("Scan Barcodes") }
    var message: Text? { Text("Scan products for instant nutrition info.") }
    var image: Image? { Image(systemName: "barcode.viewfinder") }
}

struct HealthKitTip: Tip {
    private let version = TutorialManager.shared.tipVersion
    var id: String { "healthkit_tip_v\(version)" }
    var title: Text { Text("Connect Health") }
    var message: Text? { Text("Sync steps and calories burned from Apple Health.") }
    var image: Image? { Image(systemName: "heart.fill") }
}

struct ProductSearchTip: Tip {
    private let version = TutorialManager.shared.tipVersion
    var id: String { "product_search_tip_v\(version)" }
    var title: Text { Text("Search Products") }
    var message: Text? { Text("Find saved products quickly by name.") }
    var image: Image? { Image(systemName: "magnifyingglass") }
}

