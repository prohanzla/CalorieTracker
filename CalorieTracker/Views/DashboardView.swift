// DashboardView.swift - Daily calorie tracking dashboard with Liquid Glass design
// Made by mpcode

import SwiftUI
import SwiftData
import HealthKit
import Combine
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]

    @State private var healthManager = HealthKitManager.shared
    @State private var aiManager = AIServiceManager.shared
    @State private var selectedRingPage = 0
    @State private var showingHistory = false
    @State private var showingDonation = false
    @State private var selectedHistoryPoint: DailyLog?
    @State private var isCaloriePulsing = false
    @State private var isKeyboardVisible = false

    // Donation popup preference
    @AppStorage("hideDonationPopup") private var hideDonationPopup = false

    // Unit system preference
    @AppStorage("unitSystem") private var unitSystemRaw = "Metric"

    private var useImperial: Bool {
        unitSystemRaw == "Imperial"
    }

    // User's saved daily targets from Settings
    @AppStorage("dailyCalorieTarget") private var savedCalorieTarget = 2000.0
    @AppStorage("dailyProteinTarget") private var savedProteinTarget = 50.0
    @AppStorage("dailyCarbTarget") private var savedCarbTarget = 250.0
    @AppStorage("dailyFatTarget") private var savedFatTarget = 65.0

    private var todayLog: DailyLog? {
        allLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    // Adjusted calorie target including HealthKit active calories
    private var adjustedCalorieTarget: Double {
        let baseTarget = todayLog?.calorieTarget ?? 2000
        if healthManager.isAuthorized {
            return healthManager.netCalorieTarget(baseTarget: baseTarget)
        }
        return baseTarget
    }

    private var adjustedCaloriesRemaining: Double {
        adjustedCalorieTarget - (todayLog?.totalCalories ?? 0)
    }

    private var adjustedCalorieProgress: Double {
        min((todayLog?.totalCalories ?? 0) / adjustedCalorieTarget, 1.0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic animated background
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // App header with title and branding
                        appHeaderSection

                        // Swipeable calorie ring / vitamins
                        swipeableRingSection

                        // Activity section (HealthKit)
                        if healthManager.isAuthorized {
                            activitySection
                        }

                        // Macros breakdown
                        macrosSection

                        // Today's entries
                        entriesSection
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !hideDonationPopup {
                        Button {
                            showingDonation = true
                        } label: {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.title3)
                                .foregroundStyle(.brown)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingHistory = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingDonation) {
                BuyMeCoffeeSheet()
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView()
            }
            .safeAreaInset(edge: .bottom) {
                // Custom keyboard Done button - workaround for SwiftUI toolbar bug
                if isKeyboardVisible {
                    HStack {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(.bar)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
            .onAppear {
                ensureTodayLogExists()
                // Always check and fetch HealthKit data on appear
                healthManager.checkAuthorizationStatus()
                Task {
                    // Small delay to allow authorization status to update
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                    if healthManager.isAuthorized {
                        await healthManager.fetchTodayData()
                    }
                }
            }
        }
    }

    // MARK: - App Header Section
    private var appHeaderSection: some View {
        VStack(spacing: 4) {
            // Animated shimmer title
            ShimmerText(text: "CalorieTracker")

            Text("made by mpcode")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("v1.0.0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                // AI Provider billing link
                Link(destination: billingURL(for: aiManager.selectedProvider)) {
                    HStack(spacing: 3) {
                        Image(systemName: aiManager.selectedProvider.iconName)
                            .font(.caption2)
                        Text(aiManager.selectedProvider.shortName)
                            .font(.caption2)
                        Image(systemName: "creditcard")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(aiManager.isConfigured ? .green : .orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func billingURL(for provider: AIProvider) -> URL {
        switch provider {
        case .claude:
            return URL(string: "https://console.anthropic.com/settings/billing")!
        case .openAI:
            return URL(string: "https://platform.openai.com/usage")!
        case .gemini:
            return URL(string: "https://aistudio.google.com/app/plan_information")!
        }
    }

    // MARK: - Swipeable Ring Section
    private var swipeableRingSection: some View {
        VStack(spacing: 8) {
            TabView(selection: $selectedRingPage) {
                calorieRingSection
                    .tag(0)

                vitaminsOverviewSection
                    .tag(1)

                caloriesHistorySection
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 480)

            // Swipe hint outside the cards
            HStack {
                Image(systemName: "hand.draw")
                    .font(.caption2)
                Text(swipeHintText)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }

    private var swipeHintText: String {
        switch selectedRingPage {
        case 0: return "Swipe for vitamins & history"
        case 1: return "Swipe for calories or history"
        case 2: return "Swipe for calories & vitamins"
        default: return "Swipe to explore"
        }
    }

    // MARK: - Sections
    private var calorieRingSection: some View {
        VStack(spacing: 0) {
            // Today header
            Text("Today")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.top, 8)

            // HealthKit bonus indicator
            if healthManager.isAuthorized && healthManager.todayActiveCalories > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("+\(healthManager.todayActiveCalories) kcal from activity")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
                .padding(.top, 6)
            }

            Spacer()

            // Main calorie ring
            ZStack {
                // Background ring with gradient
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.gray.opacity(0.1), .gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 24
                    )
                    .frame(width: 200, height: 200)

                // Progress ring with gradient (uses adjusted progress for HealthKit)
                Circle()
                    .trim(from: 0, to: adjustedCalorieProgress)
                    .stroke(
                        AngularGradient(
                            colors: calorieGradientColors,
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * adjustedCalorieProgress)
                        ),
                        style: StrokeStyle(lineWidth: 24, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: adjustedCalorieProgress)
                    .shadow(color: calorieRingColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    .overlay {
                        // Pulsing red glow when over target
                        if adjustedCaloriesRemaining < 0 {
                            Circle()
                                .trim(from: 0, to: adjustedCalorieProgress)
                                .stroke(Color.red, style: StrokeStyle(lineWidth: 28, lineCap: .round))
                                .frame(width: 200, height: 200)
                                .rotationEffect(.degrees(-90))
                                .opacity(isCaloriePulsing ? 0.8 : 0.4)
                                .scaleEffect(isCaloriePulsing ? 1.04 : 1.0)
                                .animation(
                                    .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                                    value: isCaloriePulsing
                                )
                        }
                    }
                    .onAppear {
                        isCaloriePulsing = true
                    }

                // Center text
                VStack(spacing: 4) {
                    Text("\(Int(todayLog?.totalCalories ?? 0))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text("of \(Int(adjustedCalorieTarget))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("kcal")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Remaining calories badge (uses adjusted remaining for HealthKit)
            HStack(spacing: 8) {
                Image(systemName: adjustedCaloriesRemaining >= 0 ? "flame.fill" : "exclamationmark.triangle.fill")
                    .font(.subheadline)
                Text(remainingText)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(adjustedCaloriesRemaining >= 0 ? .green : .red)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill((adjustedCaloriesRemaining >= 0 ? Color.green : Color.red).opacity(0.15))
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.green.opacity(0.1)), in: RoundedRectangle(cornerRadius: 24))
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
            }
        }
    }

    private var vitaminsOverviewSection: some View {
        VStack(spacing: 8) {
            // Header (fixed at top)
            HStack {
                Image(systemName: "pill.fill")
                    .foregroundStyle(.green)
                Text("Vitamins & Minerals")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()

                // Legend
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text("Over")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Scrollable content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 8) {
                    // Vitamins Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vitamins")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 4),
                            GridItem(.flexible(), spacing: 4),
                            GridItem(.flexible(), spacing: 4),
                            GridItem(.flexible(), spacing: 4)
                        ], spacing: 4) {
                            VitaminIndicator(name: "A", value: calculateVitamin(\.vitaminA), target: 800, upperLimit: 3000, unit: "mcg")
                            VitaminIndicator(name: "C", value: calculateVitamin(\.vitaminC), target: 80, upperLimit: 2000, unit: "mg")
                            VitaminIndicator(name: "D", value: calculateVitamin(\.vitaminD), target: 10, upperLimit: 100, unit: "mcg")
                            VitaminIndicator(name: "E", value: calculateVitamin(\.vitaminE), target: 12, upperLimit: 540, unit: "mg")
                            VitaminIndicator(name: "K", value: calculateVitamin(\.vitaminK), target: 75, upperLimit: nil, unit: "mcg")
                            VitaminIndicator(name: "B1", value: calculateVitamin(\.vitaminB1), target: 1.1, upperLimit: nil, unit: "mg")
                            VitaminIndicator(name: "B2", value: calculateVitamin(\.vitaminB2), target: 1.4, upperLimit: nil, unit: "mg")
                            VitaminIndicator(name: "B3", value: calculateVitamin(\.vitaminB3), target: 16, upperLimit: 35, unit: "mg")
                            VitaminIndicator(name: "B6", value: calculateVitamin(\.vitaminB6), target: 1.4, upperLimit: 25, unit: "mg")
                            VitaminIndicator(name: "B12", value: calculateVitamin(\.vitaminB12), target: 2.5, upperLimit: nil, unit: "mcg")
                            VitaminIndicator(name: "Folate", value: calculateVitamin(\.folate), target: 400, upperLimit: 1000, unit: "mcg")
                        }
                    }

                    // Minerals Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minerals")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 4),
                            GridItem(.flexible(), spacing: 4),
                            GridItem(.flexible(), spacing: 4),
                            GridItem(.flexible(), spacing: 4)
                        ], spacing: 4) {
                            VitaminIndicator(name: "Calcium", value: calculateVitamin(\.calcium), target: 1000, upperLimit: 2500, unit: "mg")
                            VitaminIndicator(name: "Iron", value: calculateVitamin(\.iron), target: 14, upperLimit: 45, unit: "mg")
                            VitaminIndicator(name: "Zinc", value: calculateVitamin(\.zinc), target: 10, upperLimit: 25, unit: "mg")
                            VitaminIndicator(name: "Magnes.", value: calculateVitamin(\.magnesium), target: 375, upperLimit: 400, unit: "mg")
                            VitaminIndicator(name: "Potass.", value: calculateVitamin(\.potassium), target: 3500, upperLimit: 6000, unit: "mg")
                            VitaminIndicator(name: "Phosph.", value: calculateVitamin(\.phosphorus), target: 700, upperLimit: 4000, unit: "mg")
                            VitaminIndicator(name: "Selenium", value: calculateVitamin(\.selenium), target: 55, upperLimit: 400, unit: "mcg")
                            VitaminIndicator(name: "Copper", value: calculateVitamin(\.copper), target: 1, upperLimit: 5, unit: "mg")
                            VitaminIndicator(name: "Mangan.", value: calculateVitamin(\.manganese), target: 2, upperLimit: 11, unit: "mg")
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.green.opacity(0.1)), in: RoundedRectangle(cornerRadius: 24))
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
            }
        }
    }

    // MARK: - Vitamin/Mineral Calculation Helper
    /// Sum vitamins from all products linked to today's entries
    private func calculateVitamin(_ keyPath: KeyPath<Product, Double?>) -> Double {
        guard let entries = todayLog?.entries else { return 0 }

        return entries.compactMap { entry -> Double? in
            guard let product = entry.product,
                  let value = product[keyPath: keyPath] else { return nil }
            // Calculate grams consumed based on calories ratio
            // This works for both gram and piece units
            // Formula: gramsConsumed = (entry.calories / product.calories) * 100
            guard product.calories > 0 else { return nil }
            let gramsConsumed = (entry.calories / product.calories) * 100.0
            let scale = gramsConsumed / 100.0
            return value * scale
        }.reduce(0, +)
    }

    // MARK: - Activity Section (HealthKit)
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundStyle(.green)
                Text("Today's Activity")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    Task {
                        await healthManager.fetchTodayData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                // Steps card
                ActivityCard(
                    icon: "figure.walk",
                    title: "Steps",
                    value: "\(healthManager.todaySteps.formatted())",
                    colour: .blue
                )

                // Active calories card
                ActivityCard(
                    icon: "flame.fill",
                    title: "Active",
                    value: "\(healthManager.todayActiveCalories) kcal",
                    colour: .orange
                )

                // Net calories card (what you can still eat)
                ActivityCard(
                    icon: "plus.forwardslash.minus",
                    title: "Earned",
                    value: "+\(healthManager.todayActiveCalories) kcal",
                    colour: .green
                )
            }

            // Explanation text
            Text("Active calories are added to your daily goal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.green.opacity(0.05)), in: RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 8)
            }
        }
    }

    private var macrosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrition")
                .font(.title3)
                .fontWeight(.bold)

            // Row 1: Protein, Carbs, Fat
            HStack(spacing: 10) {
                MacroCard(
                    title: "Protein",
                    value: todayLog?.totalProtein ?? 0,
                    targetMale: 56,
                    targetFemale: 46,
                    unit: "g",
                    colour: .blue,
                    icon: "p.circle.fill"
                )

                MacroCard(
                    title: "Carbs",
                    value: todayLog?.totalCarbs ?? 0,
                    targetMale: 300,
                    targetFemale: 225,
                    unit: "g",
                    colour: .orange,
                    icon: "c.circle.fill"
                )

                MacroCard(
                    title: "Fat",
                    value: todayLog?.totalFat ?? 0,
                    targetMale: 78,
                    targetFemale: 60,
                    unit: "g",
                    colour: .purple,
                    icon: "f.circle.fill"
                )
            }

            // Row 2: Sugar, Fibre, Salt
            HStack(spacing: 10) {
                MacroCard(
                    title: "Sugar",
                    value: todayLog?.totalSugar ?? 0,
                    targetMale: 36,
                    targetFemale: 25,
                    unit: "g",
                    colour: .pink,
                    icon: "cube.fill",
                    isMaxLimit: true
                )

                MacroCard(
                    title: "Fibre",
                    value: todayLog?.totalFibre ?? 0,
                    targetMale: 38,
                    targetFemale: 25,
                    unit: "g",
                    colour: .green,
                    icon: "leaf.fill"
                )

                MacroCard(
                    title: "Salt",
                    value: (todayLog?.totalSodium ?? 0) / 400, // Convert sodium mg to salt g (salt × 400 = sodium)
                    targetMale: 6.0,  // 6g salt = 2400mg sodium (WHO/NHS max)
                    targetFemale: 6.0,
                    unit: "g",
                    colour: .gray,
                    icon: "drop.fill",
                    isMaxLimit: true
                )
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

    // MARK: - Calories History Section
    private var caloriesHistorySection: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.orange)
                Text("Calorie History")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("Last \(min(allLogs.count, 14)) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
            .padding(.top, 8)

            // Chart
            if allLogs.count > 1 {
                let sortedLogs = allLogs.sorted { $0.date < $1.date }.suffix(14)

                Chart {
                    ForEach(Array(sortedLogs), id: \.id) { log in
                        LineMark(
                            x: .value("Date", log.date, unit: .day),
                            y: .value("Calories", log.totalCalories)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                        AreaMark(
                            x: .value("Date", log.date, unit: .day),
                            y: .value("Calories", log.totalCalories)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange.opacity(0.3), .orange.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        PointMark(
                            x: .value("Date", log.date, unit: .day),
                            y: .value("Calories", log.totalCalories)
                        )
                        .foregroundStyle(Calendar.current.isDateInToday(log.date) ? .green : .orange)
                        .symbolSize(selectedHistoryPoint?.id == log.id ? 150 : 80)
                        .annotation(position: .top, spacing: 8) {
                            if selectedHistoryPoint?.id == log.id {
                                VStack(spacing: 2) {
                                    Text("\(Int(log.totalCalories)) kcal")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Text(log.date.formatted(.dateTime.weekday(.abbreviated).day()))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                }
                            }
                        }
                    }

                    // Target line
                    RuleMark(y: .value("Target", todayLog?.calorieTarget ?? 2000))
                        .foregroundStyle(.green.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("Goal")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let xPosition = location.x
                                if let date: Date = proxy.value(atX: xPosition) {
                                    let sortedLogsArray = Array(sortedLogs)
                                    // Find closest log to the touched date
                                    if let closest = sortedLogsArray.min(by: {
                                        abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                    }) {
                                        selectedHistoryPoint = closest
                                        // Auto-dismiss after 3 seconds
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                            if selectedHistoryPoint?.id == closest.id {
                                                selectedHistoryPoint = nil
                                            }
                                        }
                                    }
                                }
                            }
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 4)

            } else {
                // Not enough data
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange.opacity(0.5))
                    Text("Track more days to see\nyour calorie history")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Keep logging your meals daily!")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Food")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Text("\(todayLog?.entries?.count ?? 0) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                    )
            }

            if let entries = todayLog?.entries, !entries.isEmpty {
                VStack(spacing: 8) {
                    ForEach(entries.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                        FoodEntryRow(entry: entry, onDelete: {
                            deleteEntry(entry)
                        })
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No food logged", systemImage: "fork.knife")
                } description: {
                    Text("Tap 'Add Food' to log your first meal")
                }
                .padding(.vertical, 20)
            }

            if todayLog?.entries?.isEmpty == false {
                HStack {
                    Image(systemName: "plusminus")
                        .font(.caption2)
                    Text("Tap +/- to adjust, × to delete")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
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

    private func deleteEntry(_ entry: FoodEntry) {
        modelContext.delete(entry)
    }

    // MARK: - Helpers
    private var calorieRingColor: Color {
        let progress = adjustedCalorieProgress
        if progress < 0.7 { return .green }
        if progress < 0.9 { return .yellow }
        if progress <= 1.0 { return .orange }
        return .red
    }

    private var calorieGradientColors: [Color] {
        let progress = adjustedCalorieProgress
        if progress < 0.7 { return [.green, .green.opacity(0.7)] }
        if progress < 0.9 { return [.green, .yellow] }
        if progress <= 1.0 { return [.yellow, .orange] }
        // Over target - solid red
        return [.red, .red.opacity(0.8)]
    }

    private var remainingText: String {
        let remaining = adjustedCaloriesRemaining
        if remaining >= 0 {
            return "\(Int(remaining)) kcal remaining"
        }
        return "\(Int(abs(remaining))) kcal over"
    }

    private func ensureTodayLogExists() {
        if let log = todayLog {
            // Sync targets if user changed them in settings
            if log.calorieTarget != savedCalorieTarget {
                log.calorieTarget = savedCalorieTarget
            }
            if log.proteinTarget != savedProteinTarget {
                log.proteinTarget = savedProteinTarget
            }
            if log.carbTarget != savedCarbTarget {
                log.carbTarget = savedCarbTarget
            }
            if log.fatTarget != savedFatTarget {
                log.fatTarget = savedFatTarget
            }
        } else {
            // Create new log with user's saved targets
            let newLog = DailyLog(
                calorieTarget: savedCalorieTarget,
                proteinTarget: savedProteinTarget,
                carbTarget: savedCarbTarget,
                fatTarget: savedFatTarget
            )
            modelContext.insert(newLog)
        }
    }
}

// MARK: - Macro Card
struct MacroCard: View {
    let title: String
    let value: Double
    let targetMale: Double
    let targetFemale: Double
    let unit: String
    let colour: Color
    let icon: String
    var isMaxLimit: Bool = false  // For sugar/salt where exceeding is bad

    // Use average target for progress calculation
    private var averageTarget: Double {
        (targetMale + targetFemale) / 2
    }

    var progress: Double {
        min(value / averageTarget, 1.0)
    }

    // For max limits, over 100% is bad (red), for others it's fine
    var progressColor: Color {
        if isMaxLimit && value > averageTarget {
            return .red
        }
        return colour
    }

    var isOverLimit: Bool {
        isMaxLimit && value > averageTarget
    }

    var body: some View {
        VStack(spacing: 6) {
            // Title with icon
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(isOverLimit ? .red : colour)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isOverLimit ? .red : .secondary)
            }

            // Progress ring
            ZStack {
                Circle()
                    .stroke(colour.opacity(0.15), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [progressColor, progressColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)

                Text(formattedValue)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isOverLimit ? .red : .primary)
            }
            .frame(width: 44, height: 44)

            // Male/Female targets
            VStack(spacing: 1) {
                HStack(spacing: 2) {
                    Text("♂")
                        .font(.system(size: 8))
                    Text(formattedTarget(targetMale))
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 2) {
                    Text("♀")
                        .font(.system(size: 8))
                    Text(formattedTarget(targetFemale))
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isOverLimit ? Color.red.opacity(0.15) : colour.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isOverLimit ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .modifier(WiggleModifier(isWiggling: isOverLimit))
    }

    private var formattedValue: String {
        if value < 10 {
            return String(format: "%.1f", value)
        }
        return "\(Int(value))"
    }

    private func formattedTarget(_ target: Double) -> String {
        if target < 10 {
            return String(format: "%.1f%@", target, unit)
        }
        return "\(Int(target))\(unit)"
    }
}

// MARK: - Activity Card (HealthKit)
struct ActivityCard: View {
    let icon: String
    let title: String
    let value: String
    let colour: Color

    var body: some View {
        VStack(spacing: 6) {
            // Icon
            ZStack {
                Circle()
                    .fill(colour.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(colour)
            }

            // Value
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Title
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colour.opacity(0.08))
        )
    }
}

// MARK: - Vitamin Indicator
struct VitaminIndicator: View {
    let name: String
    let value: Double
    let target: Double
    let upperLimit: Double?  // Tolerable upper intake level
    let unit: String

    var progress: Double {
        min(value / target, 1.0)
    }

    var percentOfTarget: Int {
        Int((value / target) * 100)
    }

    var isOverLimit: Bool {
        guard let limit = upperLimit else { return false }
        return value > limit
    }

    var isNearLimit: Bool {
        guard let limit = upperLimit else { return false }
        return value > (limit * 0.8) && value <= limit
    }

    /// Traffic light colors: green (good), amber (near limit), red (over limit)
    var statusColor: Color {
        if isOverLimit { return .red }
        if isNearLimit { return .orange }
        let percent = value / target
        if percent >= 0.5 { return .green }
        return .gray.opacity(0.6)
    }

    var body: some View {
        VStack(spacing: 1) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2.5)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)

                VStack(spacing: 0) {
                    if isOverLimit {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.red)
                    } else {
                        Text("\(percentOfTarget)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(statusColor)
                        Text("%")
                            .font(.system(size: 5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 32, height: 32)

            // Name
            Text(name)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(isOverLimit ? .red : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Value with target and unit
            VStack(spacing: 0) {
                Text("\(formattedValue)/\(formattedTarget)")
                    .font(.system(size: 6, weight: .semibold))
                    .foregroundStyle(isOverLimit ? .red : .primary)
                Text(unit)
                    .font(.system(size: 5))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .padding(.horizontal, 1)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(statusColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isOverLimit ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .modifier(WiggleModifier(isWiggling: isOverLimit))
    }

    private var formattedValue: String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else if value >= 100 {
            return "\(Int(value))"
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else if value >= 1 {
            return String(format: "%.1f", value)
        } else if value > 0 {
            return String(format: "%.2f", value)
        }
        return "0"
    }

    private var formattedTarget: String {
        if target >= 1000 {
            return String(format: "%.0fk", target / 1000)
        }
        return "\(Int(target))"
    }
}

// MARK: - Food Entry Row
struct FoodEntryRow: View {
    @Bindable var entry: FoodEntry
    let onDelete: () -> Void

    @State private var isEditingAmount = false
    @State private var editAmountText = ""
    @FocusState private var amountFieldFocused: Bool

    // Unit system preference
    @AppStorage("unitSystem") private var unitSystemRaw = "Metric"

    private var useImperial: Bool {
        unitSystemRaw == "Imperial"
    }

    // Maximum limits based on unit type
    private var maxAmount: Double {
        let unitLower = entry.unit.lowercased()
        if unitLower == "g" || unitLower == "ml" {
            return 5000  // 5kg or 5L max
        } else {
            return 100  // 100 pieces max
        }
    }

    // Formatted amount display with unit conversion
    private var formattedAmount: String {
        let unitLower = entry.unit.lowercased()

        if unitLower == "g" {
            if useImperial {
                // Convert to oz (28.35g per oz) or lb (453.6g per lb)
                let oz = entry.amount / 28.35
                if oz >= 16 {
                    let lb = entry.amount / 453.6
                    return String(format: "%.1f lb", lb)
                } else {
                    return String(format: "%.1f oz", oz)
                }
            } else {
                // Metric: show kg if over 1000g
                if entry.amount >= 1000 {
                    return String(format: "%.2f kg", entry.amount / 1000)
                } else {
                    return "\(Int(entry.amount)) g"
                }
            }
        } else if unitLower == "ml" {
            if entry.amount >= 1000 {
                return String(format: "%.2f L", entry.amount / 1000)
            } else {
                return "\(Int(entry.amount)) ml"
            }
        } else {
            // Pieces or other units
            return "\(Int(entry.amount)) \(entry.unit)"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Food icon based on type
            ZStack {
                Circle()
                    .fill(foodIconColor.opacity(0.15))
                    .frame(width: 38, height: 38)

                Text(foodEmoji)
                    .font(.system(size: 18))
            }

            // Food name and calories
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(Int(entry.calories)) kcal")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .frame(minWidth: 80, alignment: .leading)

            Spacer()

            // Quantity adjustment controls
            HStack(spacing: 4) {
                // Decrease button
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        entry.adjustAmount(by: -1)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red.opacity(entry.amount <= 1 ? 0.3 : 1))
                }
                .disabled(entry.amount <= 1)

                // Amount display - tappable for manual input
                if isEditingAmount {
                    TextField("", text: $editAmountText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 50)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .focused($amountFieldFocused)
                        .onSubmit {
                            applyAmountEdit()
                        }
                } else {
                    Text(formattedAmount)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(minWidth: 50)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onTapGesture {
                            editAmountText = "\(Int(entry.amount))"
                            isEditingAmount = true
                            amountFieldFocused = true
                        }
                }

                // Increase button (respects maxAmount based on unit type)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if entry.amount < maxAmount {
                            entry.adjustAmount(by: 1)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(entry.amount >= maxAmount ? .gray : .green)
                }
                .disabled(entry.amount >= maxAmount)
            }

            // Delete button
            Button {
                withAnimation {
                    onDelete()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func applyAmountEdit() {
        if let newAmount = Double(editAmountText), newAmount > 0 {
            // Cap based on unit type (5000g/ml or 100 pieces)
            let cappedAmount = min(newAmount, maxAmount)
            entry.setAmount(cappedAmount)
        }
        isEditingAmount = false
        amountFieldFocused = false
    }

    // MARK: - Food Icon Helpers
    private var foodEmoji: String {
        // First check if product has AI-assigned emoji
        if let emoji = entry.product?.emoji, !emoji.isEmpty {
            return emoji
        }

        // Fall back to name-based matching
        let name = entry.displayName.lowercased()

        // Fruits
        if name.contains("apple") { return "🍎" }
        if name.contains("banana") { return "🍌" }
        if name.contains("orange") { return "🍊" }
        if name.contains("grape") { return "🍇" }
        if name.contains("strawberr") { return "🍓" }
        if name.contains("watermelon") { return "🍉" }
        if name.contains("peach") { return "🍑" }
        if name.contains("pear") { return "🍐" }
        if name.contains("cherry") { return "🍒" }
        if name.contains("lemon") { return "🍋" }
        if name.contains("mango") { return "🥭" }
        if name.contains("pineapple") { return "🍍" }
        if name.contains("coconut") { return "🥥" }
        if name.contains("kiwi") { return "🥝" }
        if name.contains("blueberr") { return "🫐" }
        if name.contains("avocado") { return "🥑" }

        // Vegetables
        if name.contains("carrot") { return "🥕" }
        if name.contains("broccoli") { return "🥦" }
        if name.contains("corn") { return "🌽" }
        if name.contains("cucumber") { return "🥒" }
        if name.contains("tomato") { return "🍅" }
        if name.contains("potato") { return "🥔" }
        if name.contains("onion") { return "🧅" }
        if name.contains("garlic") { return "🧄" }
        if name.contains("pepper") { return "🌶️" }
        if name.contains("lettuce") || name.contains("salad") { return "🥬" }
        if name.contains("mushroom") { return "🍄" }
        if name.contains("eggplant") || name.contains("aubergine") { return "🍆" }

        // Proteins
        if name.contains("chicken") { return "🍗" }
        if name.contains("beef") || name.contains("steak") { return "🥩" }
        if name.contains("fish") || name.contains("salmon") || name.contains("tuna") { return "🐟" }
        if name.contains("shrimp") || name.contains("prawn") { return "🦐" }
        if name.contains("egg") { return "🥚" }
        if name.contains("bacon") { return "🥓" }

        // Dairy
        if name.contains("milk") { return "🥛" }
        if name.contains("cheese") { return "🧀" }
        if name.contains("yogurt") || name.contains("yoghurt") { return "🥛" }
        if name.contains("butter") { return "🧈" }

        // Grains & Bread
        if name.contains("bread") || name.contains("toast") { return "🍞" }
        if name.contains("rice") { return "🍚" }
        if name.contains("pasta") || name.contains("spaghetti") || name.contains("noodle") { return "🍝" }
        if name.contains("cereal") || name.contains("oat") { return "🥣" }
        if name.contains("croissant") { return "🥐" }
        if name.contains("bagel") { return "🥯" }
        if name.contains("pancake") { return "🥞" }
        if name.contains("waffle") { return "🧇" }

        // Meals
        if name.contains("pizza") { return "🍕" }
        if name.contains("burger") { return "🍔" }
        if name.contains("sandwich") { return "🥪" }
        if name.contains("taco") { return "🌮" }
        if name.contains("burrito") { return "🌯" }
        if name.contains("soup") { return "🍲" }
        if name.contains("sushi") { return "🍣" }
        if name.contains("hot dog") { return "🌭" }
        if name.contains("fries") || name.contains("chips") { return "🍟" }

        // Sweets & Snacks
        if name.contains("cake") { return "🍰" }
        if name.contains("cookie") || name.contains("biscuit") { return "🍪" }
        if name.contains("chocolate") { return "🍫" }
        if name.contains("ice cream") { return "🍦" }
        if name.contains("donut") || name.contains("doughnut") { return "🍩" }
        if name.contains("candy") || name.contains("sweet") { return "🍬" }
        if name.contains("popcorn") { return "🍿" }
        if name.contains("pretzel") { return "🥨" }

        // Drinks
        if name.contains("coffee") { return "☕" }
        if name.contains("tea") { return "🍵" }
        if name.contains("juice") { return "🧃" }
        if name.contains("smoothie") { return "🥤" }
        if name.contains("water") { return "💧" }
        if name.contains("beer") { return "🍺" }
        if name.contains("wine") { return "🍷" }

        // Nuts & Seeds
        if name.contains("nut") || name.contains("almond") || name.contains("peanut") { return "🥜" }

        // Default based on AI or product
        if entry.aiGenerated { return "✨" }
        return "🍽️"
    }

    private var foodIconColor: Color {
        let name = entry.displayName.lowercased()

        // Fruits - various colors
        if name.contains("apple") || name.contains("strawberr") || name.contains("cherry") { return .red }
        if name.contains("banana") || name.contains("lemon") || name.contains("mango") { return .yellow }
        if name.contains("orange") || name.contains("peach") || name.contains("carrot") { return .orange }
        if name.contains("grape") || name.contains("blueberr") || name.contains("eggplant") { return .purple }
        if name.contains("avocado") || name.contains("kiwi") || name.contains("broccoli") || name.contains("lettuce") || name.contains("cucumber") { return .green }

        // Proteins
        if name.contains("chicken") || name.contains("beef") || name.contains("fish") || name.contains("egg") { return .brown }

        // Dairy
        if name.contains("milk") || name.contains("cheese") || name.contains("yogurt") { return .blue }

        // Grains
        if name.contains("bread") || name.contains("rice") || name.contains("pasta") { return .brown }

        // Default
        if entry.aiGenerated { return .purple }
        return .green
    }
}

// MARK: - Shimmer Text Component
struct ShimmerText: View {
    let text: String
    @State private var shimmerPosition: CGFloat = 0

    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(text)
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundStyle(
                LinearGradient(
                    stops: orderedStops,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onReceive(timer) { _ in
                shimmerPosition += 0.012
                if shimmerPosition > 1.3 {
                    shimmerPosition = -0.3
                }
            }
    }

    // Ensure stops are always in ascending order
    private var orderedStops: [Gradient.Stop] {
        let pos = shimmerPosition
        let width: CGFloat = 0.15

        // Calculate positions, clamped to 0...1
        let leading = max(0, min(1, pos - width))
        let center = max(0, min(1, pos))
        let trailing = max(0, min(1, pos + width))

        // Build stops ensuring they're ordered
        var stops: [Gradient.Stop] = []

        // Always start with green at 0
        stops.append(.init(color: .green, location: 0))

        // Only add shimmer stops if they're visible (between 0 and 1)
        if leading > 0 && leading < 1 {
            stops.append(.init(color: .green, location: leading))
        }
        if center > 0 && center < 1 {
            stops.append(.init(color: .white, location: center))
        }
        if trailing > 0 && trailing < 1 && trailing > center {
            stops.append(.init(color: .green, location: trailing))
        }

        // Always end with green at 1
        if stops.last?.location != 1 {
            stops.append(.init(color: .green, location: 1))
        }

        return stops
    }
}

// MARK: - Wiggle Modifier
struct WiggleModifier: ViewModifier {
    let isWiggling: Bool
    @State private var wiggleAngle: Double = 0
    @State private var animationTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(wiggleAngle))
            .onChange(of: isWiggling, initial: true) { oldValue, newValue in
                // Cancel any existing animation
                animationTask?.cancel()

                if newValue {
                    // Start wiggle animation with timer-based approach
                    animationTask = Task { @MainActor in
                        var direction: Double = 1
                        while !Task.isCancelled {
                            withAnimation(.easeInOut(duration: 0.08)) {
                                wiggleAngle = 2 * direction
                            }
                            direction *= -1
                            try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
                        }
                        // When cancelled, reset to 0
                        withAnimation(.spring(duration: 0.15)) {
                            wiggleAngle = 0
                        }
                    }
                } else {
                    // Reset angle immediately when stopped
                    withAnimation(.spring(duration: 0.15)) {
                        wiggleAngle = 0
                    }
                }
            }
            .onDisappear {
                animationTask?.cancel()
            }
    }
}

// MARK: - Buy Me a Coffee Sheet
struct BuyMeCoffeeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hideDonationPopup") private var hideDonationPopup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Developer photo
                    Image("DeveloperPhoto")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                    // Greeting
                    VStack(spacing: 8) {
                        Text("Hey there!")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("I'm mpcode")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                    // Message
                    VStack(spacing: 12) {
                        Text("Thanks for using CalorieTracker!")
                            .font(.headline)

                        Text("This app is completely free and always will be. I built it because I wanted a simple, beautiful way to track my nutrition without subscriptions or ads.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("If you find it useful and want to show your appreciation, you can buy me a coffee! Every little bit helps me keep improving the app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Social Links
                    VStack(spacing: 12) {
                        Text("Connect with me")
                            .font(.headline)

                        HStack(spacing: 16) {
                            // GitHub
                            Link(destination: URL(string: "https://github.com/mp-c0de")!) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                                        .font(.title3)
                                    Text("GitHub")
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.15))
                                .clipShape(Capsule())
                            }

                            // LinkedIn
                            Link(destination: URL(string: "https://www.linkedin.com/in/mpc0de/")!) {
                                HStack(spacing: 8) {
                                    Image(systemName: "link")
                                        .font(.title3)
                                    Text("LinkedIn")
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .clipShape(Capsule())
                            }
                        }
                    }

                    // Contact info
                    VStack(spacing: 8) {
                        Text("Got feedback?")
                            .font(.headline)

                        Text("Feel free to contact me anytime for bug reports, feature requests, or just to say hi!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Link(destination: URL(string: "mailto:mpcode@icloud.com")!) {
                            HStack(spacing: 8) {
                                Image(systemName: "envelope.fill")
                                Text("mpcode@icloud.com")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue.opacity(0.1))
                    }

                    // Coffee cup decoration
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.title)
                                .foregroundStyle(.brown)
                        }
                    }

                    // PayPal QR
                    VStack(spacing: 12) {
                        Text("Scan to donate via PayPal")
                            .font(.headline)

                        Image("PayPalQR")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    }
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    }

                    // Thank you
                    Text("Thank you for your support!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()

                    // Don't show again toggle
                    Toggle(isOn: $hideDonationPopup) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Don't show this again")
                                .font(.subheadline)
                            Text("You can re-enable this in Settings")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.1))
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Support the Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self, AILogEntry.self], inMemory: true)
}
