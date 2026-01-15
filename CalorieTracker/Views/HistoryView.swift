// HistoryView.swift - Calendar-based history browser for past daily logs
// Made by mpcode

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]

    @State private var selectedDate = Date()

    private var logForSelectedDate: DailyLog? {
        allLogs.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var datesWithLogs: Set<DateComponents> {
        Set(allLogs.map { log in
            Calendar.current.dateComponents([.year, .month, .day], from: log.date)
        })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic animated background
                AppBackground()

                ScrollView {
                VStack(spacing: 20) {
                    // Calendar picker
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    .background {
                        if #available(iOS 26.0, *) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.clear)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                        }
                    }

                    // Selected day summary
                    if let log = logForSelectedDate {
                        daySummaryCard(log: log)

                        // Entries list
                        if let entries = log.entries, !entries.isEmpty {
                            entriesSection(entries: entries)
                        } else {
                            noEntriesView
                        }
                    } else {
                        noLogView
                    }
                }
                .padding()
            }
            } // Close ZStack
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectedDate = Date()
                    } label: {
                        Text("Today")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }

    // MARK: - Day Summary Card
    private func daySummaryCard(log: DailyLog) -> some View {
        VStack(spacing: 16) {
            // Date header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.formattedDate)
                        .font(.headline)
                        .fontWeight(.bold)

                    if log.isToday {
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .fontWeight(.medium)
                    }
                }

                Spacer()

                // Calorie summary badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(log.totalCalories))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(log.totalCalories > log.calorieTarget ? .red : .green)

                    Text("of \(Int(log.calorieTarget)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Macros summary
            HStack(spacing: 16) {
                MacroSummaryItem(title: "Protein", value: log.totalProtein, unit: "g", colour: .blue)
                MacroSummaryItem(title: "Carbs", value: log.totalCarbs, unit: "g", colour: .orange)
                MacroSummaryItem(title: "Fat", value: log.totalFat, unit: "g", colour: .purple)
            }

            // Additional macros
            HStack(spacing: 16) {
                MacroSummaryItem(title: "Sugar", value: log.totalSugar, unit: "g", colour: .pink)
                MacroSummaryItem(title: "Fibre", value: log.totalFibre, unit: "g", colour: .green)
                MacroSummaryItem(title: "Salt", value: log.totalSodium / 400, unit: "g", colour: .gray)
            }
        }
        .padding(20)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.green.opacity(0.1)), in: RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 8)
            }
        }
    }

    // MARK: - Entries Section
    private func entriesSection(entries: [FoodEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Food Logged")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Text("\(entries.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }

            VStack(spacing: 8) {
                ForEach(entries.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                    HistoryEntryRow(entry: entry)
                }
            }
        }
        .padding(20)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 8)
            }
        }
    }

    // MARK: - Empty States
    private var noEntriesView: some View {
        ContentUnavailableView {
            Label("No food logged", systemImage: "fork.knife")
        } description: {
            Text("No food entries were recorded on this day")
        }
        .padding(20)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            }
        }
    }

    private var noLogView: some View {
        ContentUnavailableView {
            Label("No data", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("No calorie tracking data for this date")
        }
        .padding(20)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Macro Summary Item
struct MacroSummaryItem: View {
    let title: String
    let value: Double
    let unit: String
    let colour: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(Int(value))\(unit)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(colour)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - History Entry Row
struct HistoryEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            // Food icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Text(foodEmoji)
                    .font(.system(size: 16))
            }

            // Food name and time
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Calories and amount
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.calories)) kcal")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)

                Text("\(Int(entry.amount)) \(entry.unit)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var formattedTime: String {
        entry.timestamp.shortTimeString
    }

    private var foodEmoji: String {
        FoodEmojiMapper.emoji(
            for: entry.displayName,
            productEmoji: entry.product?.emoji,
            isAIGenerated: entry.aiGenerated
        )
    }

    private var iconColor: Color {
        FoodEmojiMapper.color(for: entry.displayName, isAIGenerated: entry.aiGenerated)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self], inMemory: true)
}
