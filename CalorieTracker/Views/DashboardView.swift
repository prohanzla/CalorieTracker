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
    @State private var cloudSettings = CloudSettingsManager.shared
    @State private var selectedRingPage = 0
    @State private var showingHistory = false
    @State private var showingDonation = false
    @State private var selectedHistoryPoint: DailyLog?
    @State private var isCaloriePulsing = false
    @State private var isKeyboardVisible = false
    @State private var showingManualCaloriesSheet = false
    @State private var manualCaloriesInput = ""

    // Shared date manager - allows viewing previous days and logging to correct date
    // Note: @Observable classes don't need @State - SwiftUI tracks changes automatically
    private var dateManager: SelectedDateManager { SelectedDateManager.shared }

    // Donation popup preference
    @AppStorage("hideDonationPopup") private var hideDonationPopup = false

    // Unit system from cloud settings
    private var useImperial: Bool {
        cloudSettings.unitSystem == "imperial"
    }

    // Log for the selected date (was todayLog)
    private var selectedLog: DailyLog? {
        allLogs.first { Calendar.current.isDate($0.date, inSameDayAs: dateManager.selectedDate) }
    }

    // Convenience alias for backward compatibility
    private var todayLog: DailyLog? { selectedLog }

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

                // DEBUG: View identifier badge
                VStack {
                    HStack {
                        Text("V1")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.red))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 50)
                .padding(.leading, 8)

                ScrollView {
                    VStack(spacing: 20) {
                        // App header with title and branding
                        appHeaderSection

                        // Date navigation - view previous days
                        dateNavigationSection

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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingHistory = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gear")
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
            // Sync targets when cloudSettings change (e.g., user updates in Settings)
            .onChange(of: cloudSettings.dailyCalorieTarget) { _, _ in
                ensureTodayLogExists()
            }
            .onChange(of: cloudSettings.dailyProteinTarget) { _, _ in
                ensureTodayLogExists()
            }
            .onChange(of: cloudSettings.dailyCarbTarget) { _, _ in
                ensureTodayLogExists()
            }
            .onChange(of: cloudSettings.dailyFatTarget) { _, _ in
                ensureTodayLogExists()
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

    // MARK: - Date Navigation Section
    private var dateNavigationSection: some View {
        HStack {
            // Previous day button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    dateManager.goToPreviousDay()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Date display
            VStack(spacing: 2) {
                Text(dateManager.dateDisplayText)
                    .font(.title3)
                    .fontWeight(.bold)

                if !dateManager.isToday {
                    Text(dateManager.selectedDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 120)

            Spacer()

            // Next day button (disabled if already today)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    dateManager.goToNextDay()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(dateManager.canGoForward ? .blue : .gray.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!dateManager.canGoForward)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
        .padding(.horizontal)
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
            // Date header - shows "Today" or actual date when viewing previous days
            Text(dateManager.isToday ? "Today" : dateManager.dateDisplayText)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(dateManager.isToday ? .primary : .orange)
                .padding(.top, 8)

            // Earned calories bonus indicator (HealthKit + manual)
            if healthManager.isAuthorized && healthManager.totalEarnedCalories > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("+\(healthManager.totalEarnedCalories) kcal earned")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.green.opacity(0.15)))
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
                    // Vitamins Section - uses centralized NutrientDefinitions
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
                            ForEach(NutrientDefinitions.vitamins) { def in
                                VitaminIndicator(
                                    name: def.shortName,
                                    value: calculateNutrient(id: def.id),
                                    target: def.target,
                                    upperLimit: def.upperLimit,
                                    unit: def.unit
                                )
                            }
                        }
                    }

                    // Minerals Section - uses centralized NutrientDefinitions
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
                            ForEach(NutrientDefinitions.minerals) { def in
                                VitaminIndicator(
                                    name: def.shortName,
                                    value: calculateNutrient(id: def.id),
                                    target: def.target,
                                    upperLimit: def.upperLimit,
                                    unit: def.unit
                                )
                            }
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
    /// Sum vitamins from all products linked to today's entries (using nutrient ID from NutrientDefinitions)
    private func calculateNutrient(id: String) -> Double {
        guard let entries = todayLog?.entries else { return 0 }

        return entries.compactMap { entry -> Double? in
            guard let product = entry.product,
                  let value = product.nutrientValue(for: id) else { return nil }
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

                // Exercise minutes card
                ActivityCard(
                    icon: "timer",
                    title: "Exercise",
                    value: "\(healthManager.todayExerciseMinutes) min",
                    colour: .orange
                )

                // Earned calories card (tappable to add manual calories)
                Button {
                    manualCaloriesInput = ""
                    showingManualCaloriesSheet = true
                } label: {
                    ActivityCard(
                        icon: "plus.circle.fill",
                        title: "Earned",
                        value: "+\(healthManager.totalEarnedCalories) kcal",
                        colour: .green
                    )
                }
                .buttonStyle(.plain)
            }

            // Breakdown text
            HStack(spacing: 4) {
                Text("Workouts: \(healthManager.todayWorkoutCalories)")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("•")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Exercise: \(healthManager.todayExerciseMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(earnedModeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
        .sheet(isPresented: $showingManualCaloriesSheet) {
            manualCaloriesSheet
        }
    }

    private var earnedModeLabel: String {
        switch healthManager.earnedCaloriesMode {
        case 0: return "Workouts mode"
        case 1: return "Active mode"
        case 2: return "Total mode"
        default: return ""
        }
    }

    // MARK: - Manual Calories Sheet
    private var manualCaloriesSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: Binding(
                        get: { healthManager.earnedCaloriesMode },
                        set: { healthManager.earnedCaloriesMode = $0 }
                    )) {
                        Text("Workouts Only").tag(0)
                        Text("All Active").tag(1)
                        Text("Total Burned").tag(2)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("What counts as earned?")
                } footer: {
                    switch healthManager.earnedCaloriesMode {
                    case 0:
                        Text("Workouts: \(healthManager.todayWorkoutCalories) kcal — Only gym/exercise sessions. Best if your calorie target is TDEE (includes daily activity).")
                    case 1:
                        Text("Active: \(healthManager.todayActiveCalories) kcal — All movement including walking. Use if target is BMR + you want all activity counted.")
                    default:
                        Text("Total: \(healthManager.todayTotalCalories) kcal — Everything including resting metabolism. Only use if target is pure BMR.")
                    }
                }

                Section {
                    HStack {
                        Text("Workouts")
                        Spacer()
                        Text("\(healthManager.todayWorkoutCalories) kcal")
                            .foregroundStyle(healthManager.earnedCaloriesMode == 0 ? .green : .secondary)
                    }
                    HStack {
                        Text("All Active")
                        Spacer()
                        Text("\(healthManager.todayActiveCalories) kcal")
                            .foregroundStyle(healthManager.earnedCaloriesMode == 1 ? .green : .secondary)
                    }
                    HStack {
                        Text("Total Burned")
                        Spacer()
                        Text("\(healthManager.todayTotalCalories) kcal")
                            .foregroundStyle(healthManager.earnedCaloriesMode == 2 ? .green : .secondary)
                    }
                } header: {
                    Text("HealthKit Data")
                }

                Section {
                    HStack {
                        Text("From HealthKit")
                        Spacer()
                        Text("\(healthManager.healthKitEarnedCalories) kcal")
                            .foregroundStyle(.secondary)
                    }

                    if healthManager.manualEarnedCalories > 0 {
                        HStack {
                            Text("Manual Addition")
                            Spacer()
                            Text("+\(healthManager.manualEarnedCalories) kcal")
                                .foregroundStyle(.blue)
                        }
                    }

                    HStack {
                        Text("Total Earned")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("+\(healthManager.totalEarnedCalories) kcal")
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("Your Earned Calories")
                }

                Section {
                    TextField("Calories to add", text: $manualCaloriesInput)
                        .keyboardType(.numberPad)

                    Button {
                        if let calories = Int(manualCaloriesInput), calories > 0 {
                            healthManager.addManualCalories(calories)
                            manualCaloriesInput = ""
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Calories")
                        }
                    }
                    .disabled(Int(manualCaloriesInput) == nil || Int(manualCaloriesInput) ?? 0 <= 0)
                } header: {
                    Text("Add Manual Calories")
                } footer: {
                    Text("Add calories from activities not tracked by HealthKit.")
                }

                if healthManager.manualEarnedCalories > 0 {
                    Section {
                        Button(role: .destructive) {
                            healthManager.clearManualCalories()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear Manual Calories")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Earned Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingManualCaloriesSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // Exercise-adjusted limits for nutrients
    private var exerciseAdjustedLimits: HealthKitManager.ExerciseAdjustedLimits {
        healthManager.exerciseAdjustedLimits(
            baseSodium: 2400,  // WHO/NHS max
            basePotassium: 4700,
            baseCarbs: 300,
            baseSugar: 36,  // Using male limit as base
            baseProtein: 56,
            baseMagnesium: 420
        )
    }

    private var macrosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Nutrition")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                // Show exercise bonus indicator if user has exercised
                if healthManager.isAuthorized && healthManager.todayWorkoutCalories > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                        Text("+limits")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
                }
            }

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

            // Row 2: Added Sugar, Natural Sugar, Fibre
            HStack(spacing: 10) {
                // Added Sugar - counts against daily limit (exercise-adjusted)
                SugarMacroCard(
                    title: "Added Sugar",
                    value: todayLog?.totalAddedSugar ?? 0,
                    targetMale: exerciseAdjustedLimits.sugar,
                    targetFemale: healthManager.isAuthorized ? healthManager.exerciseAdjustedLimits(baseSugar: 25).sugar : 25,
                    unit: "g",
                    colour: .pink,
                    icon: "cube.fill",
                    isMaxLimit: true,
                    exerciseBonus: exerciseAdjustedLimits.sugarBonus
                )

                // Natural Sugar - informational only (no limit)
                NaturalSugarCard(
                    value: todayLog?.totalNaturalSugar ?? 0
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
            }

            // Row 3: Salt (with exercise-adjusted limit if applicable)
            HStack(spacing: 10) {
                // Salt with exercise-adjusted limit
                SaltMacroCard(
                    value: (todayLog?.totalSodium ?? 0) / 400, // Convert sodium mg to salt g
                    baseLimitGrams: 6.0,  // 6g salt = 2400mg sodium
                    adjustedLimitMg: exerciseAdjustedLimits.sodium,
                    exerciseBonusMg: exerciseAdjustedLimits.sodiumBonus
                )

                // Empty spacers to maintain 3-column layout
                Color.clear
                    .frame(maxWidth: .infinity)
                Color.clear
                    .frame(maxWidth: .infinity)
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
        // Only show days with actual food entries AND calories in the chart
        // Filter out logs with no entries or 0 total calories
        let logsWithEntries = allLogs.filter { log in
            guard let entries = log.entries, !entries.isEmpty else { return false }
            return log.totalCalories > 0
        }

        return VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.orange)
                Text("Calorie History")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if logsWithEntries.count > 0 {
                    Text("Last \(min(logsWithEntries.count, 14)) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                }
            }
            .padding(.top, 8)

            // Chart
            if logsWithEntries.count > 1 {
                let sortedLogs = logsWithEntries.sorted { $0.date < $1.date }.suffix(14)

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
                                // Get the plot area frame using geometry proxy to resolve the anchor
                                guard let plotFrameAnchor = proxy.plotFrame else { return }
                                let plotFrame = geometry[plotFrameAnchor]
                                // Adjust X position relative to plot area origin
                                let xPosition = location.x - plotFrame.origin.x

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
                Text(dateManager.isToday ? "Today's Food" : "\(dateManager.dateDisplayText)'s Food")
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
            // Sync targets if user changed them in settings (using CloudSettingsManager)
            if log.calorieTarget != cloudSettings.dailyCalorieTarget {
                log.calorieTarget = cloudSettings.dailyCalorieTarget
            }
            if log.proteinTarget != cloudSettings.dailyProteinTarget {
                log.proteinTarget = cloudSettings.dailyProteinTarget
            }
            if log.carbTarget != cloudSettings.dailyCarbTarget {
                log.carbTarget = cloudSettings.dailyCarbTarget
            }
            if log.fatTarget != cloudSettings.dailyFatTarget {
                log.fatTarget = cloudSettings.dailyFatTarget
            }
        } else {
            // Create new log with user's saved targets from cloud settings
            let newLog = DailyLog(
                calorieTarget: cloudSettings.dailyCalorieTarget,
                proteinTarget: cloudSettings.dailyProteinTarget,
                carbTarget: cloudSettings.dailyCarbTarget,
                fatTarget: cloudSettings.dailyFatTarget
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

// MARK: - Sugar Macro Card (with exercise bonus)
struct SugarMacroCard: View {
    let title: String
    let value: Double
    let targetMale: Double
    let targetFemale: Double
    let unit: String
    let colour: Color
    let icon: String
    var isMaxLimit: Bool = true
    var exerciseBonus: Double = 0

    private var averageTarget: Double {
        (targetMale + targetFemale) / 2
    }

    var progress: Double {
        min(value / averageTarget, 1.0)
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
                    .font(.system(size: 8))
                    .fontWeight(.medium)
                    .foregroundStyle(isOverLimit ? .red : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            // Progress ring
            ZStack {
                Circle()
                    .stroke(colour.opacity(0.15), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [isOverLimit ? .red : colour, (isOverLimit ? .red : colour).opacity(0.7)],
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

            // Targets with exercise bonus indicator
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

                // Exercise bonus indicator
                if exerciseBonus > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 6))
                        Text("+\(Int(exerciseBonus))")
                            .font(.system(size: 7))
                    }
                    .foregroundStyle(.green)
                }
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

// MARK: - Natural Sugar Card (informational, no limit)
struct NaturalSugarCard: View {
    let value: Double

    var body: some View {
        VStack(spacing: 6) {
            // Title with fruit icon
            HStack(spacing: 3) {
                Image(systemName: "leaf.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text("Natural Sugar")
                    .font(.system(size: 8))
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            // Circle (always green, no progress needed)
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))

                VStack(spacing: 0) {
                    Text(formattedValue)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("g")
                        .font(.system(size: 8))
                        .foregroundStyle(.green.opacity(0.7))
                }
            }
            .frame(width: 44, height: 44)

            // Info text
            VStack(spacing: 1) {
                Text("From fruits")
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
                Text("& dairy")
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)

                // No limit badge
                Text("No limit")
                    .font(.system(size: 6, weight: .medium))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.08))
        )
    }

    private var formattedValue: String {
        if value < 10 {
            return String(format: "%.1f", value)
        }
        return "\(Int(value))"
    }
}

// MARK: - Salt Macro Card (with exercise-adjusted limit)
struct SaltMacroCard: View {
    let value: Double  // in grams
    let baseLimitGrams: Double
    let adjustedLimitMg: Double  // sodium in mg
    let exerciseBonusMg: Double

    // Convert adjusted sodium limit to salt grams (salt × 400 = sodium)
    private var adjustedLimitGrams: Double {
        adjustedLimitMg / 400.0
    }

    var progress: Double {
        min(value / adjustedLimitGrams, 1.0)
    }

    var isOverLimit: Bool {
        value > adjustedLimitGrams
    }

    var body: some View {
        VStack(spacing: 6) {
            // Title with icon
            HStack(spacing: 3) {
                Image(systemName: "drop.fill")
                    .font(.caption2)
                    .foregroundStyle(isOverLimit ? Color.red : Color.gray)
                Text("Salt")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isOverLimit ? Color.red : Color.secondary)
            }

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [isOverLimit ? Color.red : Color.gray, (isOverLimit ? Color.red : Color.gray).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)

                Text(formattedValue)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isOverLimit ? Color.red : Color.primary)
            }
            .frame(width: 44, height: 44)

            // Target info
            VStack(spacing: 1) {
                Text("max \(String(format: "%.1fg", adjustedLimitGrams))")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)

                // Exercise bonus indicator
                if exerciseBonusMg > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 6))
                        Text("+\(String(format: "%.1fg", exerciseBonusMg / 400))")
                            .font(.system(size: 7))
                    }
                    .foregroundStyle(.green)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isOverLimit ? Color.red.opacity(0.15) : Color.gray.opacity(0.08))
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

    // Abbreviate common unit names for compact display
    private var abbreviatedUnit: String {
        let unitLower = entry.unit.lowercased()
        switch unitLower {
        case "tablespoon", "tablespoons": return "tbsp"
        case "teaspoon", "teaspoons": return "tsp"
        case "cup", "cups": return "cup"
        case "ounce", "ounces": return "oz"
        case "pound", "pounds": return "lb"
        case "piece", "pieces": return "pc"
        case "slice", "slices": return "slice"
        case "serving", "servings": return "srv"
        case "portion", "portions": return "ptn"
        case "scoop", "scoops": return "scoop"
        case "handful", "handfuls": return "hful"
        case "pinch", "pinches": return "pinch"
        case "dash", "dashes": return "dash"
        case "clove", "cloves": return "clove"
        case "stick", "sticks": return "stick"
        case "leaf", "leaves": return "leaf"
        case "sprig", "sprigs": return "sprig"
        case "bunch", "bunches": return "bunch"
        case "can", "cans": return "can"
        case "bottle", "bottles": return "btl"
        case "packet", "packets": return "pkt"
        case "bar", "bars": return "bar"
        case "sachet", "sachets": return "scht"
        default: return entry.unit
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
            // Pieces, portions, or other units - use abbreviated form
            // Show decimal for fractional amounts (e.g., 0.5 portions, 1.5 portions)
            if entry.amount == Double(Int(entry.amount)) {
                return "\(Int(entry.amount)) \(abbreviatedUnit)"
            } else {
                return String(format: "%.1f", entry.amount) + " \(abbreviatedUnit)"
            }
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
                        .onChange(of: amountFieldFocused) { _, focused in
                            // Apply edit when focus is lost (user taps elsewhere)
                            if !focused && isEditingAmount {
                                applyAmountEdit()
                            }
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

    // MARK: - Food Icon Helpers (using centralised FoodEmojiMapper)
    private var foodEmoji: String {
        FoodEmojiMapper.emoji(
            for: entry.displayName,
            productEmoji: entry.product?.emoji,
            isAIGenerated: entry.aiGenerated
        )
    }

    private var foodIconColor: Color {
        FoodEmojiMapper.color(for: entry.displayName, isAIGenerated: entry.aiGenerated)
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
                        .clipped()
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
