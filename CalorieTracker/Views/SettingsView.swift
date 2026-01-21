// SettingsView.swift - App settings, user profile, and daily targets
// Made by mpcode

import SwiftUI
import SwiftData
import HealthKit
import UniformTypeIdentifiers
import TipKit

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
    @Environment(\.dismiss) private var dismiss
    @State private var aiManager = AIServiceManager.shared
    @State private var healthManager = HealthKitManager.shared
    @State private var cloudSettings = CloudSettingsManager.shared

    // Tip - stored instance for proper dismissal tracking
    @State private var healthKitTip = HealthKitTip()

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

    // Backup/Restore state
    @Environment(\.modelContext) private var modelContext
    @State private var backupManager = DataBackupManager.shared
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportData: Data?
    @State private var showingBackupSuccess = false
    @State private var showingBackupError = false
    @State private var backupErrorMessage = ""
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false
    @State private var showingTipsResetSuccess = false

    // Cloud settings wrappers
    private var calorieTarget: Double {
        get { cloudSettings.dailyCalorieTarget }
        nonmutating set { cloudSettings.dailyCalorieTarget = newValue }
    }

    private var proteinTarget: Double {
        get { cloudSettings.dailyProteinTarget }
        nonmutating set { cloudSettings.dailyProteinTarget = newValue }
    }

    private var carbTarget: Double {
        get { cloudSettings.dailyCarbTarget }
        nonmutating set { cloudSettings.dailyCarbTarget = newValue }
    }

    private var fatTarget: Double {
        get { cloudSettings.dailyFatTarget }
        nonmutating set { cloudSettings.dailyFatTarget = newValue }
    }

    private var unitSystemRaw: String {
        get { cloudSettings.unitSystem }
        nonmutating set { cloudSettings.unitSystem = newValue }
    }

    private var genderRaw: String {
        get { cloudSettings.userGender }
        nonmutating set { cloudSettings.userGender = newValue }
    }

    private var dateOfBirthTimestamp: Double {
        get { cloudSettings.userDateOfBirth }
        nonmutating set { cloudSettings.userDateOfBirth = newValue }
    }

    private var heightCm: Double {
        get { cloudSettings.userHeightCm }
        nonmutating set { cloudSettings.userHeightCm = newValue }
    }

    private var weightKg: Double {
        get { cloudSettings.userWeightKg }
        nonmutating set { cloudSettings.userWeightKg = newValue }
    }

    // Computed properties for enums
    private var unitSystem: UnitSystem {
        get { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
        nonmutating set { unitSystemRaw = newValue.rawValue }
    }

    private var gender: Gender? {
        get { Gender(rawValue: genderRaw) }
        nonmutating set { genderRaw = newValue?.rawValue ?? "" }
    }

    private var dateOfBirth: Date? {
        get {
            guard dateOfBirthTimestamp > 0 else { return nil }
            return Date(timeIntervalSince1970: dateOfBirthTimestamp)
        }
        nonmutating set {
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
        Form {
            // DEBUG: View identifier badge
            Section {
                HStack {
                    Text("V6")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.red))
                    Text("SettingsView")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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
        // Backup export sheet
        .fileExporter(
            isPresented: $showingExporter,
            document: exportData.map { CalorieTrackerBackupDocument(data: $0) },
            contentType: .json,
            defaultFilename: backupManager.generateExportFilename()
        ) { result in
            switch result {
            case .success:
                showingBackupSuccess = true
            case .failure(let error):
                backupErrorMessage = "Export failed: \(error.localizedDescription)"
                showingBackupError = true
            }
        }
        // Backup import sheet
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else {
                    backupErrorMessage = "Cannot access the selected file"
                    showingBackupError = true
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let data = try Data(contentsOf: url)
                    importBackup(data)
                } catch {
                    backupErrorMessage = "Failed to read file: \(error.localizedDescription)"
                    showingBackupError = true
                }
            case .failure(let error):
                backupErrorMessage = "Import failed: \(error.localizedDescription)"
                showingBackupError = true
            }
        }
        // Export success alert
        .alert("Backup Exported", isPresented: $showingBackupSuccess) {
            Button("OK") { }
        } message: {
            Text("Your food data has been exported successfully. You can find it in the location you selected.")
        }
        // Import result alert
        .alert("Import Complete", isPresented: $showingImportResult) {
            Button("OK") { }
        } message: {
            if let result = importResult {
                Text("\(result.summary)\n\(result.skippedSummary)")
            } else {
                Text("Import completed")
            }
        }
        // Error alert
        .alert("Backup Error", isPresented: $showingBackupError) {
            Button("OK") { }
        } message: {
            Text(backupErrorMessage)
        }
        // Tips reset success alert
        .alert("Tutorial Hints Reset", isPresented: $showingTipsResetSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("All tutorial hints will appear again. Close settings to see them.")
        }
        .onAppear {
            initializeImperialValues()
        }
    }

    // MARK: - Sections

    private var unitSystemSection: some View {
        Section {
            Picker("Unit System", selection: Binding(
                get: { unitSystemRaw },
                set: { newValue in
                    let oldValue = unitSystemRaw
                    unitSystemRaw = newValue
                    handleUnitSystemChange(from: oldValue, to: newValue)
                }
            )) {
                Text("Metric").tag(UnitSystem.metric.rawValue)
                Text("Imperial").tag(UnitSystem.imperial.rawValue)
            }
            .pickerStyle(.segmented)
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
            Picker("", selection: Binding(
                get: { genderRaw },
                set: { genderRaw = $0 }
            )) {
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
                TextField("cm", value: Binding(
                    get: { heightCm },
                    set: { heightCm = $0 }
                ), format: .number)
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
                TextField("kg", value: Binding(
                    get: { weightKg },
                    set: { weightKg = $0 }
                ), format: .number)
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
            targetRow(label: "Calories", value: Binding(
                get: { calorieTarget },
                set: { calorieTarget = $0 }
            ), unit: "kcal", step: 100, range: 1000...5000)
            targetRow(label: "Protein", value: Binding(
                get: { proteinTarget },
                set: { proteinTarget = $0 }
            ), unit: "g", step: 5, range: 20...300)
            targetRow(label: "Carbohydrates", value: Binding(
                get: { carbTarget },
                set: { carbTarget = $0 }
            ), unit: "g", step: 10, range: 50...500)
            targetRow(label: "Fat", value: Binding(
                get: { fatTarget },
                set: { fatTarget = $0 }
            ), unit: "g", step: 5, range: 20...200)
        } header: {
            Text("Daily Targets")
        } footer: {
            Text("These targets are used to track your daily progress. Default is 2000 kcal if not calculated.")
        }
    }

    private var healthKitSection: some View {
        Section {
            // Inline tip for HealthKit
            if !healthManager.isAuthorized {
                TipView(healthKitTip)
                    .listRowBackground(Color.clear)
            }

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
                            healthKitTip.invalidate(reason: .actionPerformed)
                            Task {
                                await healthManager.requestAuthorization()
                                // Auto-sync profile data on first connect
                                healthManager.syncUserProfileToSettings()
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

                    // Profile sync button
                    Divider()
                        .padding(.vertical, 4)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-fill Profile")
                                .font(.subheadline)
                            Text("Import height, weight, DOB from Health")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task {
                                await healthManager.fetchUserProfile()
                                healthManager.syncUserProfileToSettings()
                            }
                        } label: {
                            Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    // Show what data is available from HealthKit
                    if healthManager.userHeightCm != nil || healthManager.userWeightKg != nil || healthManager.userDateOfBirth != nil {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available from Health:")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            HStack(spacing: 12) {
                                if let height = healthManager.userHeightCm {
                                    Label(String(format: "%.0f cm", height), systemImage: "ruler")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let weight = healthManager.userWeightKg {
                                    Label(String(format: "%.1f kg", weight), systemImage: "scalemass")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let dob = healthManager.userDateOfBirth {
                                    let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
                                    Label("\(age) yrs", systemImage: "birthday.cake")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
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
                Text("Active calories burned are added to your daily calorie allowance. Tap Sync to import your profile data from Apple Health.")
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

            // Reset onboarding (for testing)
            Button {
                resetOnboarding()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.orange)
                    Text("Restart Onboarding")
                    Spacer()
                    Text("For testing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        }
    }

    private func resetOnboarding() {
        cloudSettings.resetOnboarding()
        // Also reset in UserDefaults for backward compatibility
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "hasSeenTutorial")
    }

    private var dataSection: some View {
        Section {
            // iCloud Sync Status
            HStack {
                Image(systemName: "icloud")
                    .foregroundStyle(.blue)
                Text("iCloud Sync")
                Spacer()
                Text("Enabled")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            }

            // Export Backup
            Button {
                exportBackup()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.blue)
                    Text("Export Backup")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Import Backup
            Button {
                showingImporter = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(.blue)
                    Text("Import Backup")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Reset Tutorial Hints
            Button {
                TutorialManager.shared.resetAllTips()
                showingTipsResetSuccess = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset Tutorial Hints")
                }
            }

            // Reset All Data
            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Reset All Data")
                }
            }
        } header: {
            Text("Data & Backup")
        } footer: {
            Text("Your food data syncs automatically to iCloud. Use Export Backup to create a local copy you can save to Files or share.")
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
        // Use shared calculation from CloudSettingsManager
        guard let calories = cloudSettings.calculateRecommendedCalories() else { return }
        calculatedCalories = calories
        showingCalculatedCalories = true
    }

    private func calculateRecommendedMacros() {
        // Use shared calculation from CloudSettingsManager
        let macros = cloudSettings.calculateRecommendedMacros(forCalories: calorieTarget)
        proteinTarget = macros.protein
        carbTarget = macros.carbs
        fatTarget = macros.fat
    }

    // MARK: - Backup Functions

    private func exportBackup() {
        do {
            exportData = try backupManager.exportData(from: modelContext)
            showingExporter = true
        } catch {
            backupErrorMessage = "Failed to create backup: \(error.localizedDescription)"
            showingBackupError = true
        }
    }

    private func importBackup(_ data: Data) {
        do {
            let result = try backupManager.importData(data, into: modelContext)
            importResult = result
            showingImportResult = true
        } catch {
            backupErrorMessage = "Failed to import backup: \(error.localizedDescription)"
            showingBackupError = true
        }
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
