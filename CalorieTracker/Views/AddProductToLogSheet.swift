// AddProductToLogSheet.swift - Sheet for logging product with flexible amount entry
// Made by mpcode

import SwiftUI
import SwiftData

struct AddProductToLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var product: Product

    // Shared date manager for logging to correct date
    // Note: @Observable classes don't need @State - SwiftUI tracks changes automatically
    private var dateManager: SelectedDateManager { SelectedDateManager.shared }

    // Amount input
    @State private var grams: Double = 100
    @State private var gramsText: String = "100"
    @State private var portions: Double = 1

    // Input mode
    @State private var usePortions = false
    @State private var isEditingGrams = false
    @FocusState private var gramsFieldFocused: Bool
    @FocusState private var notesFieldFocused: Bool
    @State private var isKeyboardVisible = false
    @State private var fullscreenImage: IdentifiableImage? = nil

    @Query private var allLogs: [DailyLog]

    // Returns the log for the currently selected date (from dateManager)
    private var selectedDateLog: DailyLog? {
        allLogs.first { Calendar.current.isDate($0.date, inSameDayAs: dateManager.selectedDate) }
    }

    // Alias for backward compatibility
    private var todayLog: DailyLog? { selectedDateLog }

    // Calculated values
    private var effectiveGrams: Double {
        if usePortions, let portionSize = product.portionSize {
            return portionSize * portions
        }
        return grams
    }

    private var calculatedCalories: Double {
        product.caloriesFor(grams: effectiveGrams)
    }

    private var calculatedProtein: Double {
        (product.protein / 100.0) * effectiveGrams
    }

    private var calculatedCarbs: Double {
        (product.carbohydrates / 100.0) * effectiveGrams
    }

    private var calculatedFat: Double {
        (product.fat / 100.0) * effectiveGrams
    }

    private var calculatedSugar: Double {
        ((product.sugar ?? 0) / 100.0) * effectiveGrams
    }

    private var calculatedNaturalSugar: Double {
        ((product.naturalSugar ?? 0) / 100.0) * effectiveGrams
    }

    private var calculatedAddedSugar: Double {
        // If addedSugar is set, use it
        // Otherwise, if this is a processed food (has sugar but no naturalSugar),
        // treat all sugar as added sugar
        let addedSugar: Double
        if let productAddedSugar = product.addedSugar {
            addedSugar = productAddedSugar
        } else if product.naturalSugar == nil, let sugar = product.sugar {
            // Fallback: treat all sugar as added for processed foods
            addedSugar = sugar
        } else {
            addedSugar = 0
        }
        return (addedSugar / 100.0) * effectiveGrams
    }

    private var calculatedFibre: Double {
        ((product.fibre ?? 0) / 100.0) * effectiveGrams
    }

    private var calculatedSodium: Double {
        ((product.sodium ?? 0) / 100.0) * effectiveGrams
    }

    // Vitamin calculations
    private func calculateVitamin(_ value: Double?) -> Double? {
        guard let v = value else { return nil }
        return (v / 100.0) * effectiveGrams
    }

    private var hasVitaminData: Bool {
        // Uses centralized NutrientDefinitions - add new nutrients there
        NutrientDefinitions.all.contains { product.nutrientValue(for: $0.id) != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // DEBUG: View identifier badge
                    HStack {
                        Text("V8")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.red))
                        Text("AddProductToLogSheet")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Product info card
                    productInfoCard

                    // Notes section
                    notesSection

                    // Amount input section
                    amountInputSection

                    // Nutrition preview
                    nutritionPreviewSection

                    // Vitamins/Minerals section (only if product has vitamin data)
                    if hasVitaminData {
                        vitaminsMineralsSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                // Show which date entries will be logged to
                ToolbarItem(placement: .principal) {
                    if !dateManager.isToday {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text("Logging to \(dateManager.dateDisplayText)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addToLog()
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Custom keyboard Done button - only for numeric keypad (grams field)
                // Notes field has its own Return key that dismisses via .onSubmit
                if gramsFieldFocused {
                    HStack {
                        Spacer()
                        Button("Done") {
                            gramsFieldFocused = false
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
                // If product has portion size, default to portion mode
                if product.portionSize != nil {
                    usePortions = true
                }
            }
        }
    }

    // MARK: - Product Info Card
    private var productInfoCard: some View {
        VStack(spacing: 12) {
            // Product photos row (if any photos exist)
            if product.mainImageData != nil || product.imageData != nil {
                HStack(spacing: 12) {
                    // Main product photo
                    if let mainData = product.mainImageData,
                       let mainImage = UIImage(data: mainData) {
                        VStack(spacing: 4) {
                            Image(uiImage: mainImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    fullscreenImage = IdentifiableImage(image: mainImage)
                                }
                            Text("Product")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Nutrition label photo
                    if let nutritionData = product.imageData,
                       let nutritionImage = UIImage(data: nutritionData) {
                        VStack(spacing: 4) {
                            Image(uiImage: nutritionImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    fullscreenImage = IdentifiableImage(image: nutritionImage)
                                }
                            Text("Nutrition")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
            }

            // Product info row
            HStack(spacing: 16) {
                // Show placeholder only if no photos exist
                if product.mainImageData == nil && product.imageData == nil {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 70, height: 70)
                        .overlay {
                            Image(systemName: "leaf.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline)

                    if let brand = product.brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(Int(product.calories)) kcal per 100g")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let portionSize = product.portionSize,
                       let portions = product.portionsPerPackage {
                        Text("\(portions) × \(Int(portionSize))g portions")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .fullScreenCover(item: $fullscreenImage) { image in
            FullscreenImageView(image: image) {
                fullscreenImage = nil
            }
        }
    }

    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(.blue)
                Text("Notes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }

            TextField("Add notes about this product...", text: Binding(
                get: { product.notes ?? "" },
                set: { product.notes = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.plain)
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .focused($notesFieldFocused)
            .submitLabel(.done)
            .onSubmit {
                notesFieldFocused = false
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Amount Input Section
    private var amountInputSection: some View {
        VStack(spacing: 16) {
            // Mode selector (only show if product has portion info)
            if product.portionSize != nil {
                Picker("Input Mode", selection: $usePortions) {
                    Text("Grams").tag(false)
                    Text("Portions").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            if usePortions, let portionSize = product.portionSize {
                // Portions input
                VStack(spacing: 12) {
                    HStack {
                        Text("Number of Portions")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(portionSize))g each")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 20) {
                        Button {
                            if portions > 0.5 {
                                portions -= 0.5
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.red)
                        }

                        Text(portions == Double(Int(portions)) ? "\(Int(portions))" : String(format: "%.1f", portions))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .frame(minWidth: 80)

                        Button {
                            portions += 0.5
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                        }
                    }

                    Text("= \(Int(effectiveGrams))g total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            } else {
                // Amount input in grams
                VStack(spacing: 16) {
                    Text("Amount in Grams")
                        .font(.subheadline)

                    // Main input area
                    HStack(spacing: 16) {
                        // Minus button
                        Button {
                            if grams > 10 {
                                grams -= 10
                                gramsText = "\(Int(grams))"
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.red)
                        }

                        // Editable gram value
                        VStack(spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                TextField("", text: $gramsText)
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 100)
                                    .focused($gramsFieldFocused)
                                    .onChange(of: gramsText) { _, newValue in
                                        // Filter non-numeric characters
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered != newValue {
                                            gramsText = filtered
                                        }
                                        // Update grams value with max limit (5kg = 5,000g)
                                        if let value = Double(filtered), value > 0 {
                                            let cappedValue = min(value, 5000)
                                            grams = cappedValue
                                            if value > 5000 {
                                                gramsText = "5000"
                                            }
                                        }
                                    }
                                Text("g")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Tap to type exact amount")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        // Plus button
                        Button {
                            grams += 10
                            gramsText = "\(Int(grams))"
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.green)
                        }
                    }

                    // Fine adjustment buttons
                    HStack(spacing: 8) {
                        Button {
                            if grams > 1 {
                                grams -= 1
                                gramsText = "\(Int(grams))"
                            }
                        } label: {
                            Text("-1")
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 40, height: 32)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)

                        Button {
                            if grams > 5 {
                                grams -= 5
                                gramsText = "\(Int(grams))"
                            }
                        } label: {
                            Text("-5")
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 40, height: 32)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)

                        Spacer()

                        Button {
                            grams += 5
                            gramsText = "\(Int(grams))"
                        } label: {
                            Text("+5")
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 40, height: 32)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)

                        Button {
                            grams += 1
                            gramsText = "\(Int(grams))"
                        } label: {
                            Text("+1")
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 40, height: 32)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                    .padding(.horizontal)

                    // Quick amount presets
                    HStack(spacing: 10) {
                        ForEach([25, 50, 100, 150, 200], id: \.self) { amount in
                            Button {
                                grams = Double(amount)
                                gramsText = "\(amount)"
                            } label: {
                                Text("\(amount)g")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                            .tint(grams == Double(amount) ? .blue : .gray)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Nutrition Preview Section
    private var nutritionPreviewSection: some View {
        VStack(spacing: 12) {
            Text("Nutrition for \(Int(effectiveGrams))g")
                .font(.headline)

            // Main macros row
            HStack(spacing: 12) {
                NutritionPreviewCard(
                    value: Int(calculatedCalories),
                    unit: "kcal",
                    label: "Calories",
                    colour: .orange
                )

                NutritionPreviewCard(
                    value: Int(calculatedProtein),
                    unit: "g",
                    label: "Protein",
                    colour: .red
                )

                NutritionPreviewCard(
                    value: Int(calculatedCarbs),
                    unit: "g",
                    label: "Carbs",
                    colour: .blue
                )

                NutritionPreviewCard(
                    value: Int(calculatedFat),
                    unit: "g",
                    label: "Fat",
                    colour: .yellow
                )
            }

            // Sugar row - show total and natural sugar
            HStack(spacing: 12) {
                NutritionPreviewCard(
                    value: Int(calculatedSugar),
                    unit: "g",
                    label: "Sugar",
                    colour: .pink
                )

                NutritionPreviewCard(
                    value: Int(calculatedNaturalSugar),
                    unit: "g",
                    label: "Natural",
                    colour: .orange
                )

                NutritionPreviewCard(
                    value: Int(calculatedAddedSugar),
                    unit: "g",
                    label: "Added",
                    colour: .red
                )
            }

            // Additional nutrition row
            HStack(spacing: 12) {
                NutritionPreviewCard(
                    value: Int(calculatedFibre),
                    unit: "g",
                    label: "Fibre",
                    colour: .green
                )

                NutritionPreviewCard(
                    value: Int(calculatedSodium),
                    unit: "mg",
                    label: "Sodium",
                    colour: .gray
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Vitamins & Minerals Section
    private var vitaminsMineralsSection: some View {
        VStack(spacing: 12) {
            Text("Vitamins & Minerals for \(Int(effectiveGrams))g")
                .font(.headline)

            // Vitamins - uses centralized NutrientDefinitions
            let vitaminsWithValues = NutrientDefinitions.vitamins.compactMap { def -> (String, Double, String)? in
                guard let value = product.nutrientValue(for: def.id) else { return nil }
                let scaled = (value / 100.0) * effectiveGrams
                return (def.name, scaled, def.unit)
            }

            if !vitaminsWithValues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vitamins")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(vitaminsWithValues, id: \.0) { vitamin in
                            VitaminMineralRow(
                                name: vitamin.0,
                                value: vitamin.1,
                                unit: vitamin.2
                            )
                        }
                    }
                }
            }

            // Minerals - uses centralized NutrientDefinitions
            let mineralsWithValues = NutrientDefinitions.minerals.compactMap { def -> (String, Double, String)? in
                guard let value = product.nutrientValue(for: def.id) else { return nil }
                let scaled = (value / 100.0) * effectiveGrams
                return (def.name, scaled, def.unit)
            }

            if !mineralsWithValues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minerals")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(mineralsWithValues, id: \.0) { mineral in
                            VitaminMineralRow(
                                name: mineral.0,
                                value: mineral.1,
                                unit: mineral.2
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Add to Log
    private func addToLog() {
        let log: DailyLog
        if let existingLog = selectedDateLog {
            log = existingLog
        } else {
            // Create a new log for the selected date
            log = DailyLog(date: dateManager.selectedDate)
            modelContext.insert(log)
        }

        // Store the original amount and unit selection
        // If portions were selected, store as portions; otherwise as grams
        let entryAmount: Double
        let entryUnit: String

        if usePortions && product.portionSize != nil {
            entryAmount = portions
            entryUnit = portions == 1 ? "portion" : "portions"
        } else {
            entryAmount = grams
            entryUnit = "g"
        }

        let entry = FoodEntry(
            product: product,
            amount: entryAmount,
            unit: entryUnit,
            calories: calculatedCalories,
            protein: calculatedProtein,
            carbohydrates: calculatedCarbs,
            fat: calculatedFat,
            sugar: calculatedSugar,
            naturalSugar: calculatedNaturalSugar,
            addedSugar: calculatedAddedSugar,
            fibre: calculatedFibre,
            sodium: calculatedSodium
        )
        entry.dailyLog = log
        modelContext.insert(entry)

        dismiss()
    }
}

// MARK: - Nutrition Preview Card
struct NutritionPreviewCard: View {
    let value: Int
    let unit: String
    let label: String
    let colour: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(colour.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Vitamin/Mineral Row
struct VitaminMineralRow: View {
    let name: String
    let value: Double
    let unit: String

    var body: some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatValue(value) + " " + unit)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func formatValue(_ value: Double) -> String {
        if value < 1 {
            return String(format: "%.2f", value)
        } else if value < 10 {
            return String(format: "%.1f", value)
        } else {
            return "\(Int(value))"
        }
    }
}

// MARK: - Identifiable Image Wrapper
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Fullscreen Image View
struct FullscreenImageView: View {
    let image: IdentifiableImage
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image.image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                            // Limit zoom range
                            if scale < 1.0 {
                                withAnimation {
                                    scale = 1.0
                                    lastScale = 1.0
                                }
                            } else if scale > 4.0 {
                                withAnimation {
                                    scale = 4.0
                                    lastScale = 4.0
                                }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    // Double tap to reset zoom
                    withAnimation {
                        scale = 1.0
                        lastScale = 1.0
                    }
                }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
                    .padding(20)
            }
        }
        .statusBarHidden()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Product.self, DailyLog.self, FoodEntry.self, configurations: config)

    let product = Product(
        name: "Activia Yogurt",
        barcode: "1234567890",
        brand: "Danone",
        servingSize: 100,
        servingSizeUnit: "g",
        calories: 82,
        protein: 4.5,
        carbohydrates: 12.3,
        fat: 1.6,
        isCustom: false
    )
    product.portionSize = 115
    product.portionsPerPackage = 4
    container.mainContext.insert(product)

    return AddProductToLogSheet(product: product)
        .modelContainer(container)
}
