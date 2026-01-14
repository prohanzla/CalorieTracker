// AddProductToLogSheet.swift - Sheet for logging product with flexible amount entry
// Made by mpcode

import SwiftUI
import SwiftData

struct AddProductToLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let product: Product

    // Amount input
    @State private var grams: Double = 100
    @State private var gramsText: String = "100"
    @State private var portions: Double = 1

    // Input mode
    @State private var usePortions = false
    @State private var isEditingGrams = false
    @FocusState private var gramsFieldFocused: Bool

    @Query private var todayLogs: [DailyLog]

    private var todayLog: DailyLog? {
        todayLogs.first { Calendar.current.isDateInToday($0.date) }
    }

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

    private var calculatedFibre: Double {
        ((product.fibre ?? 0) / 100.0) * effectiveGrams
    }

    private var calculatedSodium: Double {
        ((product.sodium ?? 0) / 100.0) * effectiveGrams
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Product info card
                    productInfoCard

                    // Amount input section
                    amountInputSection

                    // Nutrition preview
                    nutritionPreviewSection

                    // Add button
                    Button {
                        addToLog()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add to Today's Log")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
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
        HStack(spacing: 16) {
            // Product image or placeholder
            if let imageData = product.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
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
                // Grams input
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
                                    .toolbar {
                                        ToolbarItemGroup(placement: .keyboard) {
                                            Spacer()
                                            Button("Done") {
                                                gramsFieldFocused = false
                                            }
                                            .fontWeight(.semibold)
                                        }
                                    }
                                    .onChange(of: gramsText) { _, newValue in
                                        // Filter non-numeric characters
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered != newValue {
                                            gramsText = filtered
                                        }
                                        // Update grams value
                                        if let value = Double(filtered), value > 0 {
                                            grams = value
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

            // Additional nutrition row
            HStack(spacing: 12) {
                NutritionPreviewCard(
                    value: Int(calculatedSugar),
                    unit: "g",
                    label: "Sugar",
                    colour: .pink
                )

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

    // MARK: - Add to Log
    private func addToLog() {
        let log: DailyLog
        if let existingLog = todayLog {
            log = existingLog
        } else {
            log = DailyLog()
            modelContext.insert(log)
        }

        let entry = FoodEntry(
            product: product,
            amount: effectiveGrams,
            unit: "g",
            calories: calculatedCalories,
            protein: calculatedProtein,
            carbohydrates: calculatedCarbs,
            fat: calculatedFat,
            sugar: calculatedSugar,
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
