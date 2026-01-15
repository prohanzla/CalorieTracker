// DateFormatters.swift - Centralised date formatting utilities
// Made by mpcode

import Foundation

/// Centralised date formatters to avoid creating multiple instances
/// DateFormatter creation is expensive, so we cache them
struct DateFormatters {

    // MARK: - Cached Formatters (thread-safe via static let)

    /// Short time format (e.g., "2:30 PM")
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    /// Short date format (e.g., "15/01/2026")
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .short
        return formatter
    }()

    /// Medium date format (e.g., "15 Jan 2026")
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .medium
        return formatter
    }()

    /// Full date and time (e.g., "15 January 2026 at 14:30")
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .long
        return formatter
    }()

    /// Day of week (e.g., "Monday")
    static let dayOfWeek: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    /// Short day of week (e.g., "Mon")
    static let shortDayOfWeek: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    /// Month and year (e.g., "January 2026")
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    /// Day and month (e.g., "15 Jan")
    static let dayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    /// ISO date key for storage (e.g., "2026-01-15")
    static let isoDateKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Convenience Methods

    /// Format a date for display in food logs (shows time for today, date otherwise)
    static func logTimestamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return shortTime.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday, \(shortTime.string(from: date))"
        } else {
            return "\(dayMonth.string(from: date)), \(shortTime.string(from: date))"
        }
    }

    /// Get a storage key for a specific date
    static func storageKey(for date: Date) -> String {
        isoDateKey.string(from: date)
    }

    /// Get today's date key for storage
    static var todayKey: String {
        isoDateKey.string(from: Date())
    }

    /// Format relative date (Today, Yesterday, or actual date)
    static func relativeDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return mediumDate.string(from: date)
        }
    }
}

// MARK: - Date Extension for Convenience
extension Date {
    /// Formatted as short time (e.g., "2:30 PM")
    var shortTimeString: String {
        DateFormatters.shortTime.string(from: self)
    }

    /// Formatted as short date (e.g., "15/01/2026")
    var shortDateString: String {
        DateFormatters.shortDate.string(from: self)
    }

    /// Formatted as medium date (e.g., "15 Jan 2026")
    var mediumDateString: String {
        DateFormatters.mediumDate.string(from: self)
    }

    /// Formatted as full date and time
    var fullDateTimeString: String {
        DateFormatters.fullDateTime.string(from: self)
    }

    /// Formatted as day of week (e.g., "Monday")
    var dayOfWeekString: String {
        DateFormatters.dayOfWeek.string(from: self)
    }

    /// Formatted for log display (smart timestamp)
    var logTimestamp: String {
        DateFormatters.logTimestamp(self)
    }

    /// Formatted as relative date (Today, Yesterday, or date)
    var relativeDateString: String {
        DateFormatters.relativeDate(self)
    }

    /// Storage key format (yyyy-MM-dd)
    var storageKey: String {
        DateFormatters.storageKey(for: self)
    }
}
