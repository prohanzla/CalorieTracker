// SettingsView.swift - App settings, user profile, and daily targets
// Made by mpcode

import SwiftUI
import SwiftData
import HealthKit

// MARK: - Enums
enum Gender: String, CaseIterable, Codable {
    case male = "Male"
    case female = "Female"

    var icon: String {
        switch self {
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        }
    }
}

// NOTE: HealthKit Integration implemented
// - Reads daily steps and active calories burned from Apple Health
// - Shows activity data in dashboard when connected
// - Active calories can be added to daily calorie allowance

enum UnitSystem: String, CaseIterable, Codable {
    case metric = "Metric"
    case imperial = "Imperial"

    var weightUnit: String {
        switch self {
        case .metric: return "kg"
        case .imperial: return "lbs"
        }
    }

    var heightUnit: String {
        switch self {
        case .metric: return "cm"
        case .imperial: return "ft/in"
        }
    }
}

struct SettingsView: View {
    @State private var aiManager = AIServiceManager.shared
    @State private var healthManager = HealthKitManager.shared

    // Daily Targets
    @AppStorage("dailyCalorieTarget") private var calorieTarget = 2000.0
    @AppStorage("dailyProteinTarget") private var proteinTarget = 50.0
    @AppStorage("dailyCarbTarget") private var carbTarget = 250.0
    @AppStorage("dailyFatTarget") private var fatTarget = 65.0

    // Unit System
    @AppStorage("unitSystem") private var unitSystemRaw = UnitSystem.metric.rawValue

    // User Profile
    @AppStorage("userGender") private var genderRaw = ""
    @AppStorage("userDateOfBirth") private var dateOfBirthTimestamp: Double = 0
    @AppStorage("userHeightCm") private var heightCm: Double = 0
    @AppStorage("userWeightKg") private var weightKg: Double = 0

    // Imperial input helpers
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 8
    @State private var weightLbs: Double = 0

    // Keyboard focus
    @FocusState private var focusedField: FocusedField?
    @State private var isKeyboardVisible = false

    enum FocusedField {
        case height, weight
    }

    @State private var showingResetConfirmation = false
    @State private var showingCalculatedCalories = false
    @State private var calculatedCalories: Int = 0

    // Computed properties for enums
    private var unitSystem: UnitSystem {
        get { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
        set { unitSystemRaw = newValue.rawValue }
    }

    private var gender: Gender? {
        get { Gender(rawValue: genderRaw) }
        set { genderRaw = newValue?.rawValue ?? "" }
    }

    private var dateOfBirth: Date? {
        get {
            guard dateOfBirthTimestamp > 0 else { return nil }
            return Date(timeIntervalSince1970: dateOfBirthTimestamp)
        }
        set {
            dateOfBirthTimestamp = newValue?.timeIntervalSince1970 ?? 0
        }
    }

    private var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
        return ageComponents.year
    }

    private var canCalculateCalories: Bool {
        gender != nil && dateOfBirth != nil && heightCm > 0 && weightKg > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                unitSystemSection
                userProfileSection
                calculateButtonSection
                dailyTargetsSection
                healthKitSection
                aiSection
                aiBillingSection
                aboutSection
                dataSection
            }
            .safeAreaInset(edge: .bottom) {
                // Custom keyboard Done button - workaround for SwiftUI toolbar bug
                if isKeyboardVisible {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
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
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset All Data",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete all products, food entries, and logs. This cannot be undone.")
            }
            .alert("Recommended Daily Calories", isPresented: $showingCalculatedCalories) {
                Button("Use This") {
                    calorieTarget = Double(calculatedCalories)
                    calculateRecommendedMacros()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Based on your profile, your recommended daily intake is \(calculatedCalories) kcal.\n\nThis uses the Mifflin-St Jeor equation, the most accurate BMR formula.")
            }
            .onAppear {
                initializeImperialValues()
            }
        }
    }

    // MARK: - Sections

    private var unitSystemSection: some View {
        Section {
            Picker("Unit System", selection: $unitSystemRaw) {
                Text("Metric").tag(UnitSystem.metric.rawValue)
                Text("Imperial").tag(UnitSystem.imperial.rawValue)
            }
            .pickerStyle(.segmented)
            .onChange(of: unitSystemRaw) { oldValue, newValue in
                handleUnitSystemChange(from: oldValue, to: newValue)
            }
        } header: {
            Text("Units")
        }
    }

    private var userProfileSection: some View {
        Section {
            genderRow
            dateOfBirthRow
            heightRow
            weightRow
        } header: {
            Text("Your Profile")
        } footer: {
            if canCalculateCalories {
                Text("Tap 'Calculate' to set your recommended daily calories based on your BMR.")
            } else {
                Text("Enter your profile to calculate recommended daily calorie intake.")
            }
        }
    }

    private var genderRow: some View {
        HStack {
            Text("Gender")
            Spacer()
            Picker("", selection: $genderRaw) {
                Text("Not Set").tag("")
                Text("Male").tag(Gender.male.rawValue)
                Text("Female").tag(Gender.female.rawValue)
            }
            .pickerStyle(.menu)
        }
    }

    private var dateOfBirthRow: some View {
        HStack {
            Text("Date of Birth")
            Spacer()
            if dateOfBirthTimestamp > 0 {
                DatePicker("", selection: Binding(
                    get: { Date(timeIntervalSince1970: dateOfBirthTimestamp) },
                    set: { dateOfBirthTimestamp = $0.timeIntervalSince1970 }
                ), in: ...Date(), displayedComponents: .date)
                .labelsHidden()

                if let age = age {
                    Text("(\(age) yrs)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Set") {
                    let calendar = Calendar.current
                    if let date = calendar.date(byAdding: .year, value: -25, to: Date()) {
                        dateOfBirthTimestamp = date.timeIntervalSince1970
                    }
                }
                .foregroundStyle(.blue)
            }
        }
    }

    @ViewBuilder
    private var heightRow: some View {
        if unitSystem == .metric {
            HStack {
                Text("Height")
                Spacer()
                TextField("cm", value: $heightCm, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($focusedField, equals: .height)
                Text("cm")
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack {
                Text("Height")
                Spacer()
                Picker("", selection: $heightFeet) {
                    ForEach(3...8, id: \.self) { ft in
                        Text("\(ft) ft").tag(ft)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: heightFeet) { _, _ in updateHeightFromImperial() }

                Picker("", selection: $heightInches) {
                    ForEach(0...11, id: \.self) { inch in
                        Text("\(inch) in").tag(inch)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: heightInches) { _, _ in updateHeightFromImperial() }
            }
        }
    }

    @ViewBuilder
    private var weightRow: some View {
        if unitSystem == .metric {
            HStack {
                Text("Weight")
                Spacer()
                TextField("kg", value: $weightKg, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($focusedField, equals: .weight)
                Text("kg")
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack {
                Text("Weight")
                Spacer()
                TextField("lbs", value: $weightLbs, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($focusedField, equals: .weight)
                    .onChange(of: weightLbs) { _, newValue in
                        weightKg = newValue / 2.20462
                    }
                Text("lbs")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var calculateButtonSection: some View {
        if canCalculateCalories {
            Section {
                Button {
                    calculateRecommendedCalories()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.title3)
                        Text("Calculate My Daily Calories")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    private var dailyTargetsSection: some View {
        Section {
            targetRow(label: "Calories", value: $calorieTarget, unit: "kcal", step: 100, range: 1000...5000)
            targetRow(label: "Protein", value: $proteinTarget, unit: "g", step: 5, range: 20...300)
            targetRow(label: "Carbohydrates", value: $carbTarget, unit: "g", step: 10, range: 50...500)
            targetRow(label: "Fat", value: $fatTarget, unit: "g", step: 5, range: 20...200)
        } header: {
            Text("Daily Targets")
        } footer: {
            Text("These targets are used to track your daily progress. Default is 2000 kcal if not calculated.")
        }
    }

    private var healthKitSection: some View {
        Section {
            if healthManager.isHealthKitAvailable {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(healthManager.isAuthorized ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .frame(width: 44, height: 44)
                        if healthManager.isConnecting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "heart.fill")
                                .font(.title2)
                                .foregroundStyle(healthManager.isAuthorized ? .green : .red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health")
                            .font(.headline)

                        Text(healthManager.isConnecting ? "Connecting..." : (healthManager.isAuthorized ? "Connected" : "Not connected"))
                            .font(.caption)
                            .foregroundStyle(healthManager.isAuthorized ? .green : .secondary)
                    }

                    Spacer()

                    if healthManager.isConnecting {
                        // Show loading indicator
                        ProgressView()
                            .controlSize(.small)
                    } else if healthManager.isAuthorized {
                        // Show disconnect button
                        Button("Disconnect") {
                            healthManager.disconnect()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                    } else {
                        Button("Connect") {
                            Task {
                                await healthManager.requestAuthorization()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                if healthManager.isAuthorized {
                    // Show current stats
                    HStack {
                        Label("\(healthManager.todaySteps.formatted()) steps", systemImage: "figure.walk")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label("\(healthManager.todayActiveCalories) kcal burned", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.top, 4)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("HealthKit not available on this device")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Activity Tracking")
        } footer: {
            if healthManager.isAuthorized {
                Text("Active calories burned are added to your daily calorie allowance.")
            } else {
                Text("Connect to Apple Health to track your steps and calories burned. This helps adjust your daily calorie goal based on activity.")
            }
        }
    }

    private var aiSection: some View {
        Section {
            NavigationLink {
                AISettingsView()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(aiManager.isConfigured ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: aiManager.selectedProvider.iconName)
                            .font(.title2)
                            .foregroundStyle(aiManager.isConfigured ? .green : .orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(aiManager.selectedProvider.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(aiManager.isConfigured ? "Ready to use" : "API key required")
                            .font(.caption)
                            .foregroundStyle(aiManager.isConfigured ? .green : .orange)
                    }

                    Spacer()
                }
            }
        } header: {
            Text("AI Features")
        } footer: {
            Text("Choose between Claude, Gemini (free tier), or ChatGPT for nutrition label scanning.")
        }
    }

    private var aiBillingSection: some View {
        Section {
            // Claude/Anthropic billing
            Link(destination: URL(string: "https://console.anthropic.com/settings/billing")!) {
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                        .foregroundStyle(.purple)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude Billing")
                            .foregroundStyle(.primary)
                        Text("console.anthropic.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }

            // OpenAI billing
            Link(destination: URL(string: "https://platform.openai.com/usage")!) {
                HStack(spacing: 12) {
                    Image(systemName: "brain")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OpenAI Billing")
                            .foregroundStyle(.primary)
                        Text("platform.openai.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }

            // Google Gemini billing
            Link(destination: URL(string: "https://aistudio.google.com/app/plan_information")!) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gemini Billing")
                            .foregroundStyle(.primary)
                        Text("aistudio.google.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("AI Billing & Usage")
        } footer: {
            Text("Check your API usage and add credits for each AI provider. Gemini offers a free tier.")
        }
    }

    // Donation popup setting
    @AppStorage("hideDonationPopup") private var hideDonationPopup = false

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Made by")
                Spacer()
                Text("mpcode")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://github.com/mp-c0de/CalorieTracker")!) {
                HStack {
                    Text("GitHub Repository")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }

            // Support/Donation toggle
            Toggle(isOn: Binding(
                get: { !hideDonationPopup },
                set: { hideDonationPopup = !$0 }
            )) {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundStyle(.brown)
                    Text("Show Support Button")
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Reset All Data")
                }
            }
        }
    }

    // MARK: - Helpers

    private func targetRow(label: String, value: Binding<Double>, unit: String, step: Double, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Stepper(
                "\(Int(value.wrappedValue)) \(unit)",
                value: value,
                in: range,
                step: step
            )
        }
    }

    private func hideKeyboard() {
        focusedField = nil
    }

    private func initializeImperialValues() {
        if unitSystem == .imperial && heightCm > 0 {
            weightLbs = weightKg * 2.20462
            let totalInches = heightCm / 2.54
            heightFeet = max(3, min(8, Int(totalInches / 12)))
            heightInches = max(0, min(11, Int(totalInches.truncatingRemainder(dividingBy: 12))))
        }
    }

    private func handleUnitSystemChange(from oldValue: String, to newValue: String) {
        let oldSystem = UnitSystem(rawValue: oldValue) ?? .metric
        let newSystem = UnitSystem(rawValue: newValue) ?? .metric

        if oldSystem == .metric && newSystem == .imperial {
            // Metric to Imperial
            weightLbs = weightKg * 2.20462
            let totalInches = heightCm / 2.54
            heightFeet = max(3, min(8, Int(totalInches / 12)))
            heightInches = max(0, min(11, Int(totalInches.truncatingRemainder(dividingBy: 12))))
        } else if oldSystem == .imperial && newSystem == .metric {
            // Imperial to Metric
            weightKg = weightLbs / 2.20462
            heightCm = (Double(heightFeet) * 12 + Double(heightInches)) * 2.54
        }
    }

    private func updateHeightFromImperial() {
        heightCm = (Double(heightFeet) * 12 + Double(heightInches)) * 2.54
    }

    private func calculateRecommendedCalories() {
        guard let gender = gender,
              let age = age,
              heightCm > 0,
              weightKg > 0 else { return }

        // Mifflin-St Jeor Equation for BMR
        let bmr: Double
        switch gender {
        case .male:
            bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        case .female:
            bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        }

        // Use sedentary multiplier (1.2) as baseline
        // TODO: In future, read actual activity from HealthKit and adjust dynamically
        let sedentaryMultiplier = 1.2
        let tdee = bmr * sedentaryMultiplier

        calculatedCalories = Int(tdee.rounded())
        showingCalculatedCalories = true
    }

    private func calculateRecommendedMacros() {
        // Standard macro split: 30% protein, 40% carbs, 30% fat
        let proteinCalories = calorieTarget * 0.30
        let carbCalories = calorieTarget * 0.40
        let fatCalories = calorieTarget * 0.30

        // Convert to grams (4 cal/g protein, 4 cal/g carbs, 9 cal/g fat)
        proteinTarget = proteinCalories / 4
        carbTarget = carbCalories / 4
        fatTarget = fatCalories / 9
    }

    private func resetAllData() {
        // Clear all API keys
        for provider in AIProvider.allCases {
            AIServiceManager.shared.setAPIKey("", for: provider)
        }

        // Reset profile data
        genderRaw = ""
        dateOfBirthTimestamp = 0
        heightCm = 0
        weightKg = 0

        // Reset targets to defaults
        calorieTarget = 2000
        proteinTarget = 50
        carbTarget = 250
        fatTarget = 65
    }
}

#Preview {
    SettingsView()
}
