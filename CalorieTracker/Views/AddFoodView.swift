// AddFoodView.swift - Main food entry view with multiple input methods
// Made by mpcode

import SwiftUI
import SwiftData

struct AddFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var claudeService = ClaudeAPIService()
    @State private var showingScanner = false
    @State private var showingCamera = false
    @State private var showingManualEntry = false
    @State private var quickInputText = ""
    @State private var isProcessingAI = false
    @State private var errorMessage: String?
    @State private var showingError = false

    // Success feedback
    @State private var showingSuccess = false
    @State private var successMessage = ""
    @State private var lastLoggedFood: String?
    @State private var lastLoggedCalories: Int?

    // Nutrition confirmation
    @State private var pendingNutrition: ParsedNutrition?
    @State private var pendingImage: UIImage?
    @State private var showingNutritionConfirmation = false

    @Query private var todayLogs: [DailyLog]
    @Query(sort: \Product.dateAdded, order: .reverse) private var recentProducts: [Product]

    private var todayLog: DailyLog? {
        todayLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Quick AI input section
                        quickInputSection

                        // Action buttons
                        actionButtonsSection

                        // Recent products
                        recentProductsSection
                    }
                    .padding()
                }
                .navigationTitle("Add Food")

                // Success toast overlay
                if showingSuccess {
                    VStack {
                        Spacer()
                        successToast
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 20)
                    }
                    .animation(.spring(duration: 0.4), value: showingSuccess)
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { barcode in
                    handleScannedBarcode(barcode)
                }
            }
            .sheet(isPresented: $showingCamera) {
                NutritionCameraView { image in
                    Task {
                        await processNutritionImage(image)
                    }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
            .sheet(isPresented: $showingNutritionConfirmation) {
                if let nutrition = pendingNutrition {
                    NutritionConfirmationView(
                        nutrition: nutrition,
                        image: pendingImage,
                        onConfirm: { editedNutrition in
                            saveConfirmedNutrition(editedNutrition)
                        },
                        onCancel: {
                            pendingNutrition = nil
                            pendingImage = nil
                        }
                    )
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Success Toast
    private var successToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Food Logged!")
                    .font(.headline)
                    .foregroundStyle(.white)

                if let food = lastLoggedFood, let cals = lastLoggedCalories {
                    Text("\(food) • \(cals) kcal added")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            Spacer()

            Button {
                withAnimation {
                    showingSuccess = false
                }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding()
        .background(Color.green.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .padding(.horizontal)
    }

    // MARK: - Sections
    private var quickInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Add with AI", systemImage: "sparkles")
                .font(.headline)

            HStack {
                TextField("e.g., \"I had one apple\"", text: $quickInputText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isProcessingAI)

                Button {
                    Task {
                        await processQuickInput()
                    }
                } label: {
                    if isProcessingAI {
                        ProgressView()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                    }
                }
                .disabled(quickInputText.isEmpty || isProcessingAI)
            }

            Text("Describe what you ate and AI will estimate the calories")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ActionButton(
                    title: "Scan Barcode",
                    icon: "barcode.viewfinder",
                    colour: .blue
                ) {
                    showingScanner = true
                }

                ActionButton(
                    title: "Scan Label",
                    icon: "camera.fill",
                    colour: .green
                ) {
                    showingCamera = true
                }
            }

            ActionButton(
                title: "Manual Entry",
                icon: "square.and.pencil",
                colour: .orange
            ) {
                showingManualEntry = true
            }
        }
    }

    private var recentProductsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Products")
                .font(.headline)

            if recentProducts.isEmpty {
                ContentUnavailableView {
                    Label("No products yet", systemImage: "cart")
                } description: {
                    Text("Scan a barcode or add a product manually")
                }
            } else {
                ForEach(recentProducts.prefix(5)) { product in
                    RecentProductRow(product: product) {
                        addProductEntry(product)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions
    private func processQuickInput() async {
        guard !quickInputText.isEmpty else { return }
        let inputText = quickInputText

        isProcessingAI = true
        defer { isProcessingAI = false }

        do {
            let estimate = try await claudeService.estimateFromPrompt(inputText)

            let entry = FoodEntry(
                customFoodName: estimate.foodName,
                amount: estimate.amount,
                unit: estimate.unit,
                calories: estimate.calories,
                protein: estimate.protein,
                carbohydrates: estimate.carbohydrates,
                fat: estimate.fat,
                aiGenerated: true,
                aiPrompt: inputText
            )

            addEntryToTodayLog(entry)
            quickInputText = ""

            // Show success feedback
            showSuccessFeedback(food: estimate.foodName, calories: Int(estimate.calories))
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func processNutritionImage(_ image: UIImage) async {
        isProcessingAI = true
        defer { isProcessingAI = false }

        do {
            let nutrition = try await claudeService.parseNutritionLabel(image: image)

            // Store for confirmation instead of adding directly
            await MainActor.run {
                pendingNutrition = nutrition
                pendingImage = image
                showingNutritionConfirmation = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func saveConfirmedNutrition(_ nutrition: ParsedNutrition) {
        let product = Product(
            name: nutrition.productName ?? "Scanned Product",
            servingSize: nutrition.servingSize ?? 100,
            servingSizeUnit: nutrition.servingSizeUnit ?? "g",
            calories: nutrition.calories,
            protein: nutrition.protein ?? 0,
            carbohydrates: nutrition.carbohydrates ?? 0,
            fat: nutrition.fat ?? 0,
            isCustom: false
        )

        // Add optional nutrition data
        product.saturatedFat = nutrition.saturatedFat
        product.fibre = nutrition.fibre
        product.sugar = nutrition.sugar
        product.sodium = nutrition.sodium
        product.vitaminA = nutrition.vitaminA
        product.vitaminC = nutrition.vitaminC
        product.vitaminD = nutrition.vitaminD
        product.calcium = nutrition.calcium
        product.iron = nutrition.iron
        product.imageData = pendingImage?.jpegData(compressionQuality: 0.7)

        modelContext.insert(product)
        addProductEntry(product)

        // Clear pending data
        pendingNutrition = nil
        pendingImage = nil
        showingNutritionConfirmation = false

        // Show success
        showSuccessFeedback(food: product.name, calories: Int(product.calories))
    }

    private func handleScannedBarcode(_ barcode: String) {
        // Check if product exists
        let descriptor = FetchDescriptor<Product>(
            predicate: #Predicate { $0.barcode == barcode }
        )

        if let existingProduct = try? modelContext.fetch(descriptor).first {
            addProductEntry(existingProduct)
            showSuccessFeedback(food: existingProduct.name, calories: Int(existingProduct.calories))
        } else {
            // Show manual entry with barcode pre-filled
            showingManualEntry = true
        }
    }

    private func addProductEntry(_ product: Product) {
        let entry = FoodEntry(
            product: product,
            amount: product.servingSize,
            unit: product.servingSizeUnit,
            calories: product.calories,
            protein: product.protein,
            carbohydrates: product.carbohydrates,
            fat: product.fat
        )
        addEntryToTodayLog(entry)
    }

    private func addEntryToTodayLog(_ entry: FoodEntry) {
        if let log = todayLog {
            entry.dailyLog = log
            modelContext.insert(entry)
        } else {
            let newLog = DailyLog()
            modelContext.insert(newLog)
            entry.dailyLog = newLog
            modelContext.insert(entry)
        }
    }

    private func showSuccessFeedback(food: String, calories: Int) {
        lastLoggedFood = food
        lastLoggedCalories = calories

        withAnimation {
            showingSuccess = true
        }

        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showingSuccess = false
            }
        }
    }
}

// MARK: - Nutrition Confirmation View
struct NutritionConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    let nutrition: ParsedNutrition
    let image: UIImage?
    let onConfirm: (ParsedNutrition) -> Void
    let onCancel: () -> Void

    @State private var productName: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var servingSize: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Scanned image preview
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Confidence indicator
                    if let confidence = nutrition.confidence {
                        HStack {
                            Image(systemName: confidence > 0.7 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(confidence > 0.7 ? .green : .orange)
                            Text("AI Confidence: \(Int(confidence * 100))%")
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding()
                        .background(confidence > 0.7 ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Text("Please verify the extracted data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Editable fields
                    VStack(spacing: 16) {
                        EditableField(label: "Product Name", value: $productName)
                        EditableField(label: "Serving Size (g)", value: $servingSize, isNumeric: true)
                        EditableField(label: "Calories (kcal)", value: $calories, isNumeric: true)
                        EditableField(label: "Protein (g)", value: $protein, isNumeric: true)
                        EditableField(label: "Carbohydrates (g)", value: $carbs, isNumeric: true)
                        EditableField(label: "Fat (g)", value: $fat, isNumeric: true)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("Confirm Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Product") {
                        let edited = ParsedNutrition(
                            productName: productName.isEmpty ? nil : productName,
                            servingSize: Double(servingSize),
                            servingSizeUnit: "g",
                            calories: Double(calories) ?? nutrition.calories,
                            protein: Double(protein),
                            carbohydrates: Double(carbs),
                            fat: Double(fat),
                            saturatedFat: nutrition.saturatedFat,
                            fibre: nutrition.fibre,
                            sugar: nutrition.sugar,
                            sodium: nutrition.sodium,
                            vitaminA: nutrition.vitaminA,
                            vitaminC: nutrition.vitaminC,
                            vitaminD: nutrition.vitaminD,
                            calcium: nutrition.calcium,
                            iron: nutrition.iron,
                            confidence: nutrition.confidence
                        )
                        onConfirm(edited)
                        dismiss()
                    }
                }
            }
            .onAppear {
                productName = nutrition.productName ?? ""
                servingSize = nutrition.servingSize.map { String(Int($0)) } ?? "100"
                calories = String(Int(nutrition.calories))
                protein = nutrition.protein.map { String(Int($0)) } ?? "0"
                carbs = nutrition.carbohydrates.map { String(Int($0)) } ?? "0"
                fat = nutrition.fat.map { String(Int($0)) } ?? "0"
            }
        }
    }
}

struct EditableField: View {
    let label: String
    @Binding var value: String
    var isNumeric: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(label, text: $value)
                .textFieldStyle(.roundedBorder)
                .keyboardType(isNumeric ? .decimalPad : .default)
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let icon: String
    let colour: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(colour.gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Recent Product Row
struct RecentProductRow: View {
    let product: Product
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if let brand = product.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(Int(product.calories)) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    AddFoodView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self], inMemory: true)
}
