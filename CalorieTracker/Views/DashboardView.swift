// DashboardView.swift - Daily calorie tracking dashboard
// Made by mpcode

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]

    private var todayLog: DailyLog? {
        allLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Calorie ring
                    calorieRingSection

                    // Macros breakdown
                    macrosSection

                    // Today's entries
                    entriesSection
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Navigate to history
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .onAppear {
                ensureTodayLogExists()
            }
        }
    }

    // MARK: - Sections
    private var calorieRingSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)

                // Progress ring
                Circle()
                    .trim(from: 0, to: todayLog?.calorieProgress ?? 0)
                    .stroke(
                        calorieRingColor,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: todayLog?.calorieProgress)

                // Center text
                VStack(spacing: 4) {
                    Text("\(Int(todayLog?.totalCalories ?? 0))")
                        .font(.system(size: 44, weight: .bold))
                    Text("of \(Int(todayLog?.calorieTarget ?? 2000))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Remaining calories
            HStack {
                Image(systemName: todayLog?.caloriesRemaining ?? 0 >= 0 ? "flame" : "exclamationmark.triangle")
                Text(remainingText)
                    .font(.headline)
            }
            .foregroundStyle(todayLog?.caloriesRemaining ?? 0 >= 0 ? .green : .red)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var macrosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macros")
                .font(.headline)

            HStack(spacing: 16) {
                MacroCard(
                    title: "Protein",
                    value: todayLog?.totalProtein ?? 0,
                    target: todayLog?.proteinTarget ?? 50,
                    unit: "g",
                    colour: .blue
                )

                MacroCard(
                    title: "Carbs",
                    value: todayLog?.totalCarbs ?? 0,
                    target: todayLog?.carbTarget ?? 250,
                    unit: "g",
                    colour: .orange
                )

                MacroCard(
                    title: "Fat",
                    value: todayLog?.totalFat ?? 0,
                    target: todayLog?.fatTarget ?? 65,
                    unit: "g",
                    colour: .purple
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Food")
                    .font(.headline)
                Spacer()
                Text("\(todayLog?.entries?.count ?? 0) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let entries = todayLog?.entries, !entries.isEmpty {
                ForEach(entries.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                    FoodEntryRow(entry: entry, onDelete: {
                        deleteEntry(entry)
                    })
                }
            } else {
                ContentUnavailableView {
                    Label("No food logged", systemImage: "fork.knife")
                } description: {
                    Text("Tap 'Add Food' to log your first meal")
                }
            }

            if todayLog?.entries?.isEmpty == false {
                Text("Swipe left to delete")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func deleteEntry(_ entry: FoodEntry) {
        modelContext.delete(entry)
    }

    // MARK: - Helpers
    private var calorieRingColor: Color {
        let progress = todayLog?.calorieProgress ?? 0
        if progress < 0.7 { return .green }
        if progress < 0.9 { return .yellow }
        if progress <= 1.0 { return .orange }
        return .red
    }

    private var remainingText: String {
        let remaining = todayLog?.caloriesRemaining ?? 0
        if remaining >= 0 {
            return "\(Int(remaining)) kcal remaining"
        }
        return "\(Int(abs(remaining))) kcal over"
    }

    private func ensureTodayLogExists() {
        if todayLog == nil {
            let newLog = DailyLog()
            modelContext.insert(newLog)
        }
    }
}

// MARK: - Macro Card
struct MacroCard: View {
    let title: String
    let value: Double
    let target: Double
    let unit: String
    let colour: Color

    var progress: Double {
        min(value / target, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(colour.opacity(0.2), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(colour, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(value))")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(width: 50, height: 50)

            Text("\(Int(target))\(unit)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Food Entry Row
struct FoodEntryRow: View {
    let entry: FoodEntry
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showingDeleteConfirm = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background
            HStack {
                Spacer()
                Button {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 50)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Main content
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("\(Int(entry.amount))\(entry.unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(entry.calories)) kcal")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if entry.aiGenerated {
                        Label("AI", systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(Color(.systemBackground))
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = max(value.translation.width, -70)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(duration: 0.3)) {
                            if value.translation.width < -50 {
                                offset = -70
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .confirmationDialog("Delete Entry", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                withAnimation {
                    onDelete()
                }
            }
            Button("Cancel", role: .cancel) {
                withAnimation(.spring(duration: 0.3)) {
                    offset = 0
                }
            }
        } message: {
            Text("Remove \(entry.displayName) from today's log?")
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self], inMemory: true)
}
