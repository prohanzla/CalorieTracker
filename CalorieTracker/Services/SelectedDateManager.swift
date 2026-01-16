// SelectedDateManager.swift - Shared state for currently selected date across views
// Made by mpcode

import Foundation
import SwiftUI

/// Observable class that manages the selected date across all views
/// This allows the user to navigate to previous days in DashboardView
/// and have food entries logged to the correct date
@Observable
class SelectedDateManager {
    static let shared = SelectedDateManager()

    /// The currently selected date for viewing/logging entries
    var selectedDate: Date = Date()

    private init() {}

    // MARK: - Date Navigation Helpers

    /// Whether the selected date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// Whether we can navigate forward (only if not already on today)
    var canGoForward: Bool {
        !isToday
    }

    /// Whether the selected date is in the future (should not allow logging)
    var isFutureDate: Bool {
        selectedDate > Date()
    }

    /// Display text for the selected date
    var dateDisplayText: String {
        if isToday {
            return "Today"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, d MMM"
            return formatter.string(from: selectedDate)
        }
    }

    // MARK: - Navigation Methods

    /// Navigate to previous day
    func goToPreviousDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            selectedDate = newDate
        }
    }

    /// Navigate to next day (only if not already today)
    func goToNextDay() {
        guard canGoForward else { return }
        if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
            selectedDate = newDate
        }
    }

    /// Reset to today
    func goToToday() {
        selectedDate = Date()
    }
}
