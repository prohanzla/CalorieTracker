// OnboardingView.swift - First launch onboarding flow
// Made by mpcode

import SwiftUI

struct OnboardingView: View {
    let onComplete: (Bool) -> Void  // Bool indicates whether to show tutorial

    @State private var currentStep = 0
    @State private var cloudSettings = CloudSettingsManager.shared

    // Local state for calorie/macro targets (synced on save)
    @State private var calorieTarget = 2000.0
    @State private var proteinTarget = 50.0
    @State private var carbTarget = 250.0
    @State private var fatTarget = 65.0

    // Local state for inputs
    @State private var selectedGender: Gender?
    @State private var dateOfBirth = Date()
    @State private var heightInput = ""
    @State private var weightInput = ""
    @State private var selectedUnitSystem: UnitSystem = .metric

    // Keyboard handling
    @FocusState private var isTextFieldFocused: Bool
    @State private var isKeyboardVisible = false

    // Validation limits
    private let minAge = 13
    private let maxAge = 120
    private let minHeightCm = 50.0
    private let maxHeightCm = 300.0
    private let minHeightInches = 20.0
    private let maxHeightInches = 120.0
    private let minWeightKg = 20.0
    private let maxWeightKg = 500.0
    private let minWeightLbs = 44.0
    private let maxWeightLbs = 1100.0

    enum Gender: String, CaseIterable {
        case male = "Male"
        case female = "Female"
    }

    enum UnitSystem: String, CaseIterable {
        case metric = "metric"
        case imperial = "imperial"
    }

    private let totalSteps = 4

    var body: some View {
        ZStack {
            // DEBUG: View identifier badge
            VStack {
                HStack {
                    Text("V13")
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
            .padding(.top, 60)
            .padding(.leading, 16)
            .zIndex(100)

            // Gradient background
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                progressBar
                    .padding(.top, 20)
                    .padding(.horizontal, 40)

                // Content
                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    profileStep.tag(1)
                    goalsStep.tag(2)
                    completeStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
        }
        // Keyboard Done button using safeAreaInset pattern
        .safeAreaInset(edge: .bottom) {
            if isKeyboardVisible {
                HStack {
                    Spacer()
                    Button("Done") {
                        isTextFieldFocused = false
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.trailing, 8)
                    .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGray5))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .frame(width: geo.size.width * (Double(currentStep + 1) / Double(totalSteps)), height: 8)
                    .animation(.easeInOut, value: currentStep)
            }
        }
        .frame(height: 8)
    }

    // MARK: - Step 0: Welcome
    private var welcomeStep: some View {
        VStack(spacing: 30) {
            Spacer()

            // App icon/logo area
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 150, height: 150)

                Image(systemName: "flame.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("Welcome to")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))

                Text("CalorieTracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Your personal nutrition companion")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "sparkles", text: "AI-powered food logging")
                featureRow(icon: "barcode.viewfinder", text: "Barcode scanning")
                featureRow(icon: "chart.pie.fill", text: "Nutrition tracking")
                featureRow(icon: "heart.fill", text: "Health insights")
            }
            .padding(.horizontal, 40)

            Spacer()

            Button {
                withAnimation { currentStep = 1 }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 30)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Step 1: Profile
    private var profileStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("About You")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Help us personalise your experience")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 40)

                VStack(spacing: 20) {
                    // Gender selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gender")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 12) {
                            ForEach(Gender.allCases, id: \.self) { gender in
                                Button {
                                    selectedGender = gender
                                } label: {
                                    HStack {
                                        Image(systemName: gender == .male ? "figure.stand" : "figure.stand.dress")
                                        Text(gender.rawValue)
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(selectedGender == gender ? .blue : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(selectedGender == gender ? Color.white : Color.white.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }

                    // Date of birth
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date of Birth")
                            .font(.headline)
                            .foregroundStyle(.white)

                        DatePicker("", selection: $dateOfBirth, in: dateOfBirthRange, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .colorScheme(.dark)
                    }

                    // Unit system
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unit System")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 12) {
                            ForEach(UnitSystem.allCases, id: \.self) { unit in
                                Button {
                                    selectedUnitSystem = unit
                                } label: {
                                    Text(unit == .metric ? "Metric (kg, cm)" : "Imperial (lb, ft)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(selectedUnitSystem == unit ? .blue : .white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(selectedUnitSystem == unit ? Color.white : Color.white.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }

                    // Height
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Height")
                            .font(.headline)
                            .foregroundStyle(.white)

                        TextField(selectedUnitSystem == .metric ? "Height in cm" : "Height in inches", text: $heightInput)
                            .keyboardType(.decimalPad)
                            .focused($isTextFieldFocused)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)

                        if let message = heightValidationMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    // Weight
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight")
                            .font(.headline)
                            .foregroundStyle(.white)

                        TextField(selectedUnitSystem == .metric ? "Weight in kg" : "Weight in lbs", text: $weightInput)
                            .keyboardType(.decimalPad)
                            .focused($isTextFieldFocused)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)

                        if let message = weightValidationMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal, 30)

                Spacer(minLength: 40)

                Button {
                    saveProfile()
                    withAnimation { currentStep = 2 }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canContinueProfile ? Color.white : Color.white.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canContinueProfile)
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }

    private var canContinueProfile: Bool {
        selectedGender != nil && !heightInput.isEmpty && !weightInput.isEmpty && isHeightValid && isWeightValid
    }

    // Date of birth range (age 13-120)
    private var dateOfBirthRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let maxDate = calendar.date(byAdding: .year, value: -minAge, to: Date()) ?? Date()
        let minDate = calendar.date(byAdding: .year, value: -maxAge, to: Date()) ?? Date()
        return minDate...maxDate
    }

    // Height validation
    private var isHeightValid: Bool {
        guard let height = Double(heightInput) else { return false }
        if selectedUnitSystem == .metric {
            return height >= minHeightCm && height <= maxHeightCm
        } else {
            return height >= minHeightInches && height <= maxHeightInches
        }
    }

    // Weight validation
    private var isWeightValid: Bool {
        guard let weight = Double(weightInput) else { return false }
        if selectedUnitSystem == .metric {
            return weight >= minWeightKg && weight <= maxWeightKg
        } else {
            return weight >= minWeightLbs && weight <= maxWeightLbs
        }
    }

    // Height validation message
    private var heightValidationMessage: String? {
        guard !heightInput.isEmpty else { return nil }
        guard Double(heightInput) != nil else { return "Please enter a valid number" }
        if !isHeightValid {
            if selectedUnitSystem == .metric {
                return "Height must be between \(Int(minHeightCm))-\(Int(maxHeightCm)) cm"
            } else {
                return "Height must be between \(Int(minHeightInches))-\(Int(maxHeightInches)) inches"
            }
        }
        return nil
    }

    // Weight validation message
    private var weightValidationMessage: String? {
        guard !weightInput.isEmpty else { return nil }
        guard Double(weightInput) != nil else { return "Please enter a valid number" }
        if !isWeightValid {
            if selectedUnitSystem == .metric {
                return "Weight must be between \(Int(minWeightKg))-\(Int(maxWeightKg)) kg"
            } else {
                return "Weight must be between \(Int(minWeightLbs))-\(Int(maxWeightLbs)) lbs"
            }
        }
        return nil
    }

    private func saveProfile() {
        cloudSettings.userGender = selectedGender?.rawValue ?? ""
        cloudSettings.userDateOfBirth = dateOfBirth.timeIntervalSince1970
        cloudSettings.unitSystem = selectedUnitSystem.rawValue

        if selectedUnitSystem == .metric {
            // Clamp values within valid ranges
            let height = Double(heightInput) ?? 0
            cloudSettings.userHeightCm = min(max(height, minHeightCm), maxHeightCm)
            let weight = Double(weightInput) ?? 0
            cloudSettings.userWeightKg = min(max(weight, minWeightKg), maxWeightKg)
        } else {
            // Convert imperial to metric for storage (with clamping)
            let inches = min(max(Double(heightInput) ?? 0, minHeightInches), maxHeightInches)
            cloudSettings.userHeightCm = inches * 2.54
            let lbs = min(max(Double(weightInput) ?? 0, minWeightLbs), maxWeightLbs)
            cloudSettings.userWeightKg = lbs * 0.453592
        }

        // Auto-calculate recommended calories based on profile
        calculateRecommendedCalories()
    }

    private func saveGoals() {
        cloudSettings.dailyCalorieTarget = calorieTarget
        cloudSettings.dailyProteinTarget = proteinTarget
        cloudSettings.dailyCarbTarget = carbTarget
        cloudSettings.dailyFatTarget = fatTarget
    }

    // MARK: - Step 2: Goals
    private var goalsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Your Goals")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Based on your profile, here are your recommended targets")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                VStack(spacing: 20) {
                    // Calorie target (auto-calculated from profile)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Calories")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack {
                            Text("\(Int(calorieTarget))")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("kcal")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Slider(value: $calorieTarget, in: 1200...4000, step: 50)
                            .tint(.white)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Macro targets
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Macro Targets")
                            .font(.headline)
                            .foregroundStyle(.white)

                        macroSlider(label: "Protein", value: $proteinTarget, range: 20...200, unit: "g", color: .red)
                        macroSlider(label: "Carbs", value: $carbTarget, range: 50...400, unit: "g", color: .green)
                        macroSlider(label: "Fat", value: $fatTarget, range: 20...150, unit: "g", color: .yellow)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 30)

                Spacer(minLength: 40)

                Button {
                    saveGoals()
                    withAnimation { currentStep = 3 }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }

    private func macroSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(Int(value.wrappedValue))\(unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            Slider(value: value, in: range, step: 5)
                .tint(color)
        }
    }

    private func calculateRecommendedCalories() {
        // Use shared calculation from CloudSettingsManager (same as Settings)
        guard let calories = cloudSettings.calculateRecommendedCalories() else { return }

        // Use exact value (same as Settings view)
        calorieTarget = Double(calories)

        // Calculate macros using shared function
        let macros = cloudSettings.calculateRecommendedMacros(forCalories: calorieTarget)
        proteinTarget = macros.protein
        carbTarget = macros.carbs
        fatTarget = macros.fat
    }

    // MARK: - Step 3: Complete
    private var completeStep: some View {
        VStack(spacing: 30) {
            Spacer()

            // Success animation
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 150, height: 150)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Your profile is ready. Would you like a quick tour of the app?")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onComplete(true)  // Start tutorial
                } label: {
                    HStack {
                        Image(systemName: "hand.point.up.left.fill")
                        Text("Start Tutorial")
                    }
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    onComplete(false)  // Skip tutorial
                } label: {
                    Text("Skip, I'll explore myself")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    OnboardingView { showTutorial in
        print("Onboarding complete, show tutorial: \(showTutorial)")
    }
}
