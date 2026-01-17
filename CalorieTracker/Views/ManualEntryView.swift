// ManualEntryView.swift - Manual product/food entry form with AI scan option
// Made by mpcode

import SwiftUI
import SwiftData

// Helper struct for passing product to sheet reliably
struct ProductItem: Identifiable {
    let id = UUID()
    let product: Product
}

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Initial barcode if coming from scanner
    var initialBarcode: String = ""

    @State private var aiManager = AIServiceManager.shared

    // Basic info
    @State private var name = ""
    @State private var brand = ""
    @State private var barcode = ""
    @State private var servingSize = "100"

    // Main nutrition
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbohydrates = ""
    @State private var fat = ""
    @State private var saturatedFat = ""
    @State private var transFat = ""
    @State private var fibre = ""
    @State private var sugar = ""
    @State private var naturalSugar = ""
    @State private var addedSugar = ""
    @State private var sodium = ""
    @State private var cholesterol = ""

    // Vitamins & Minerals - using dictionary with NutrientDefinitions IDs
    @State private var nutrientValues: [String: String] = [:]

    // Portion info (optional - for multi-portion products)
    @State private var portionSize = ""      // grams per portion
    @State private var portionsPerPackage = ""  // number of portions

    // UI state
    @State private var showingMainNutrition = true
    @State private var showingVitamins = false
    @State private var showingMinerals = false
    @State private var showingPortionInfo = false
    @State private var showingCamera = false
    @State private var isProcessingAI = false
    @State private var isEstimatingVitamins = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var capturedImage: UIImage?

    // Duplicate detection
    @State private var existingProduct: Product?
    @State private var showingDuplicateAlert = false

    // Show log sheet after save - using Identifiable wrapper for reliable sheet binding
    @State private var productToLog: ProductItem?

    // Keyboard state - for Done button on number pad
    @State private var isKeyboardVisible = false

    var isValid: Bool {
        !name.isEmpty && !calories.isEmpty
    }

    // Helper to create binding for nutrient dictionary
    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { nutrientValues[id] ?? "" },
            set: { nutrientValues[id] = $0 }
        )
    }

    // Helper to set nutrient value from AI response
    private func setNutrientFromAI(_ value: Double?, id: String, decimals: Int) {
        if let v = value {
            nutrientValues[id] = String(format: "%.\(decimals)f", v)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // DEBUG: View identifier badge
                Section {
                    HStack {
                        Text("V9")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.red))
                        Text("ManualEntryView")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Scan nutrition label button
                Section {
                    Button {
                        showingCamera = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scan Nutrition Label")
                                    .font(.headline)
                                Text("Use AI to auto-fill nutrition data")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isProcessingAI {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isProcessingAI || !aiManager.isConfigured)

                    if !aiManager.isConfigured {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Add API key in Settings to use AI scanning")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // AI Vitamin Estimation button
                    if !name.isEmpty && aiManager.isConfigured {
                        Button {
                            Task {
                                await estimateVitaminsWithAI()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.purple.gradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Estimate Vitamins with AI")
                                        .font(.headline)
                                    Text("Auto-fill average vitamin content for \"\(name)\"")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if isEstimatingVitamins {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(isEstimatingVitamins)
                    }
                }

                // Basic info
                Section("Product Information") {
                    TextField("Product Name *", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    HStack {
                        TextField("Barcode", text: $barcode)
                            .keyboardType(.numberPad)
                        if !barcode.isEmpty {
                            Image(systemName: "barcode")
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Portion info (optional)
                Section {
                    DisclosureGroup("Portion Info (Optional)", isExpanded: $showingPortionInfo) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("For multi-portion products like yogurt pots")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Text("Portion Size")
                                Spacer()
                                TextField("e.g. 115", text: $portionSize)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Text("g")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, alignment: .leading)
                            }

                            HStack {
                                Text("Portions per Package")
                                Spacer()
                                TextField("e.g. 4", text: $portionsPerPackage)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                        }
                    }
                } footer: {
                    Text("Example: A 4-pack yogurt with 115g pots")
                }

                // Main nutrition (per 100g or 100ml)
                Section {
                    DisclosureGroup("Main Nutrition (per 100g)", isExpanded: $showingMainNutrition) {
                        NutritionTextField(label: "Calories *", value: $calories, unit: "kcal")
                        NutritionTextField(label: "Protein", value: $protein, unit: "g")
                        NutritionTextField(label: "Carbohydrates", value: $carbohydrates, unit: "g")
                        NutritionTextField(label: "Fat", value: $fat, unit: "g")
                        NutritionTextField(label: "Saturated Fat", value: $saturatedFat, unit: "g")
                        NutritionTextField(label: "Trans Fat", value: $transFat, unit: "g")
                        NutritionTextField(label: "Fibre", value: $fibre, unit: "g")
                        NutritionTextField(label: "Natural Sugar", value: $naturalSugar, unit: "g")
                        NutritionTextField(label: "Added Sugar", value: $addedSugar, unit: "g")
                        NutritionTextField(label: "Sodium (Salt)", value: $sodium, unit: "mg")
                        NutritionTextField(label: "Cholesterol", value: $cholesterol, unit: "mg")
                    }
                }

                // Vitamins (per 100g or 100ml) - iterates over NutrientDefinitions
                Section {
                    DisclosureGroup("Vitamins (per 100g)", isExpanded: $showingVitamins) {
                        ForEach(NutrientDefinitions.vitamins) { def in
                            NutritionTextField(
                                label: def.name,
                                value: binding(for: def.id),
                                unit: def.unit
                            )
                        }
                    }
                }

                // Minerals (per 100g or 100ml) - iterates over NutrientDefinitions
                Section {
                    DisclosureGroup("Minerals (per 100g)", isExpanded: $showingMinerals) {
                        ForEach(NutrientDefinitions.minerals) { def in
                            NutritionTextField(
                                label: def.name,
                                value: binding(for: def.id),
                                unit: def.unit
                            )
                        }
                    }
                }

                // Required fields note
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("* Required fields")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("All nutrition values are stored per 100g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        checkAndSaveProduct()
                    }
                    .disabled(!isValid)
                }
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
                if !initialBarcode.isEmpty {
                    barcode = initialBarcode
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                NutritionScanView { image in
                    capturedImage = image
                    Task {
                        await processNutritionImage(image)
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .alert("Product Already Exists", isPresented: $showingDuplicateAlert) {
                Button("Use Existing") {
                    if let existing = existingProduct {
                        productToLog = ProductItem(product: existing)
                    }
                }
                Button("Update Existing") {
                    if let existing = existingProduct {
                        updateExistingProduct(existing)
                    }
                }
                Button("Add as New", role: .destructive) {
                    saveNewProduct()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let existing = existingProduct {
                    Text("A product with this barcode already exists: \"\(existing.name)\". What would you like to do?")
                }
            }
            .sheet(item: $productToLog, onDismiss: {
                dismiss()
            }) { item in
                AddProductToLogSheet(product: item.product)
            }
        }
    }

    // MARK: - Duplicate Check
    private func checkAndSaveProduct() {
        // Check for existing product with same barcode
        if !barcode.isEmpty {
            let barcodeToCheck = barcode
            let descriptor = FetchDescriptor<Product>(
                predicate: #Predicate { $0.barcode == barcodeToCheck }
            )

            if let existing = try? modelContext.fetch(descriptor).first {
                existingProduct = existing
                showingDuplicateAlert = true
                return
            }
        }

        // No duplicate found, save normally
        saveNewProduct()
    }

    private func updateExistingProduct(_ existing: Product) {
        // Update existing product with new values
        existing.name = name
        existing.brand = brand.isEmpty ? nil : brand
        existing.calories = Double(calories) ?? 0
        existing.protein = Double(protein) ?? 0
        existing.carbohydrates = Double(carbohydrates) ?? 0
        existing.fat = Double(fat) ?? 0

        // Portion info
        existing.portionSize = Double(portionSize)
        existing.portionsPerPackage = Int(portionsPerPackage)

        // Main nutrition
        existing.saturatedFat = Double(saturatedFat)
        existing.transFat = Double(transFat)
        existing.fibre = Double(fibre)

        // Sugar: only Natural and Added, calculate total from both
        let naturalSugarValue = Double(naturalSugar) ?? 0
        let addedSugarValue = Double(addedSugar) ?? 0
        existing.naturalSugar = naturalSugarValue > 0 ? naturalSugarValue : nil
        existing.addedSugar = addedSugarValue > 0 ? addedSugarValue : nil
        existing.sugar = (naturalSugarValue + addedSugarValue) > 0 ? (naturalSugarValue + addedSugarValue) : nil

        existing.sodium = Double(sodium)
        existing.cholesterol = Double(cholesterol)

        // Vitamins & Minerals - iterate over NutrientDefinitions
        for def in NutrientDefinitions.all {
            if let valueStr = nutrientValues[def.id], !valueStr.isEmpty {
                existing.setNutrientValue(Double(valueStr), for: def.id)
            } else {
                existing.setNutrientValue(nil, for: def.id)
            }
        }

        // Update image if captured
        if let image = capturedImage {
            existing.imageData = image.jpegData(compressionQuality: 0.7)
        }

        productToLog = ProductItem(product: existing)
    }

    private func saveNewProduct() {
        let product = createProduct()
        modelContext.insert(product)
        productToLog = ProductItem(product: product)
    }

    // MARK: - AI Processing
    private func processNutritionImage(_ image: UIImage) async {
        isProcessingAI = true
        defer { isProcessingAI = false }

        do {
            let nutrition = try await aiManager.parseNutritionLabelFull(image: image)

            // Log the successful AI response
            await MainActor.run {
                let logEntry = AILogEntry(
                    requestType: "nutrition_label_manual",
                    provider: aiManager.selectedProvider.displayName,
                    input: "[Image scan - Manual Entry]",
                    output: formatNutritionFullForLog(nutrition),
                    success: true
                )
                modelContext.insert(logEntry)
            }

            await MainActor.run {
                // Auto-fill all fields from AI response
                if let productName = nutrition.productName { name = productName }
                if let size = nutrition.servingSize { servingSize = String(Int(size)) }
                // Unit is always grams now

                calories = String(Int(nutrition.calories))
                if let p = nutrition.protein { protein = String(format: "%.1f", p) }
                if let c = nutrition.carbohydrates { carbohydrates = String(format: "%.1f", c) }
                if let f = nutrition.fat { fat = String(format: "%.1f", f) }
                if let sf = nutrition.saturatedFat { saturatedFat = String(format: "%.1f", sf) }
                if let tf = nutrition.transFat { transFat = String(format: "%.1f", tf) }
                if let fb = nutrition.fibre { fibre = String(format: "%.1f", fb) }
                // Sugar handling: only Natural and Added sugar
                if let ns = nutrition.naturalSugar { naturalSugar = String(format: "%.1f", ns) }
                if let as_ = nutrition.addedSugar {
                    addedSugar = String(format: "%.1f", as_)
                } else if let s = nutrition.sugar, nutrition.naturalSugar == nil {
                    // If AI only returned total sugar (no breakdown), treat as added sugar
                    addedSugar = String(format: "%.1f", s)
                }
                if let sod = nutrition.sodium { sodium = String(Int(sod)) }
                if let ch = nutrition.cholesterol { cholesterol = String(Int(ch)) }

                // Vitamins & Minerals - map from ParsedNutritionFull to dictionary using NutrientDefinitions
                setNutrientFromAI(nutrition.vitaminA, id: "vitaminA", decimals: 1)
                setNutrientFromAI(nutrition.vitaminC, id: "vitaminC", decimals: 1)
                setNutrientFromAI(nutrition.vitaminD, id: "vitaminD", decimals: 1)
                setNutrientFromAI(nutrition.vitaminE, id: "vitaminE", decimals: 2)
                setNutrientFromAI(nutrition.vitaminK, id: "vitaminK", decimals: 1)
                setNutrientFromAI(nutrition.vitaminB1, id: "vitaminB1", decimals: 3)
                setNutrientFromAI(nutrition.vitaminB2, id: "vitaminB2", decimals: 3)
                setNutrientFromAI(nutrition.vitaminB3, id: "vitaminB3", decimals: 2)
                setNutrientFromAI(nutrition.vitaminB5, id: "vitaminB5", decimals: 2)
                setNutrientFromAI(nutrition.vitaminB6, id: "vitaminB6", decimals: 3)
                setNutrientFromAI(nutrition.vitaminB7, id: "vitaminB7", decimals: 1)
                setNutrientFromAI(nutrition.vitaminB12, id: "vitaminB12", decimals: 2)
                setNutrientFromAI(nutrition.folate, id: "folate", decimals: 1)
                setNutrientFromAI(nutrition.calcium, id: "calcium", decimals: 1)
                setNutrientFromAI(nutrition.iron, id: "iron", decimals: 1)
                setNutrientFromAI(nutrition.potassium, id: "potassium", decimals: 1)
                setNutrientFromAI(nutrition.magnesium, id: "magnesium", decimals: 1)
                setNutrientFromAI(nutrition.zinc, id: "zinc", decimals: 2)
                setNutrientFromAI(nutrition.phosphorus, id: "phosphorus", decimals: 1)
                setNutrientFromAI(nutrition.selenium, id: "selenium", decimals: 1)
                setNutrientFromAI(nutrition.copper, id: "copper", decimals: 2)
                setNutrientFromAI(nutrition.manganese, id: "manganese", decimals: 2)
                setNutrientFromAI(nutrition.chromium, id: "chromium", decimals: 1)
                setNutrientFromAI(nutrition.molybdenum, id: "molybdenum", decimals: 1)
                setNutrientFromAI(nutrition.iodine, id: "iodine", decimals: 1)
                setNutrientFromAI(nutrition.chloride, id: "chloride", decimals: 1)

                // Expand sections that have data
                showingVitamins = NutrientDefinitions.vitamins.contains { !(nutrientValues[$0.id] ?? "").isEmpty }
                showingMinerals = NutrientDefinitions.minerals.contains { !(nutrientValues[$0.id] ?? "").isEmpty }
            }
        } catch {
            // Log the failed AI response
            await MainActor.run {
                let logEntry = AILogEntry(
                    requestType: "nutrition_label_manual",
                    provider: aiManager.selectedProvider.displayName,
                    input: "[Image scan - Manual Entry]",
                    output: "",
                    success: false,
                    errorMessage: error.localizedDescription
                )
                modelContext.insert(logEntry)

                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    // Format nutrition data for AI log
    private func formatNutritionFullForLog(_ nutrition: ParsedNutritionFull) -> String {
        var lines: [String] = []
        if let name = nutrition.productName { lines.append("Product: \(name)") }
        if let serving = nutrition.servingSize { lines.append("Serving: \(serving)\(nutrition.servingSizeUnit ?? "g")") }
        lines.append("Calories: \(nutrition.calories) kcal")
        if let protein = nutrition.protein { lines.append("Protein: \(protein)g") }
        if let carbs = nutrition.carbohydrates { lines.append("Carbs: \(carbs)g") }
        if let fat = nutrition.fat { lines.append("Fat: \(fat)g") }
        if let sugar = nutrition.sugar { lines.append("Sugar: \(sugar)g") }
        if let fibre = nutrition.fibre { lines.append("Fibre: \(fibre)g") }
        if let sodium = nutrition.sodium { lines.append("Sodium: \(sodium)mg") }

        // Vitamins
        lines.append("\n--- Vitamins ---")
        if let v = nutrition.vitaminA { lines.append("Vitamin A: \(v) mcg") }
        if let v = nutrition.vitaminC { lines.append("Vitamin C: \(v) mg") }
        if let v = nutrition.vitaminD { lines.append("Vitamin D: \(v) mcg") }
        if let v = nutrition.vitaminE { lines.append("Vitamin E: \(v) mg") }
        if let v = nutrition.vitaminK { lines.append("Vitamin K: \(v) mcg") }
        if let v = nutrition.vitaminB1 { lines.append("Vitamin B1: \(v) mg") }
        if let v = nutrition.vitaminB2 { lines.append("Vitamin B2: \(v) mg") }
        if let v = nutrition.vitaminB3 { lines.append("Vitamin B3: \(v) mg") }
        if let v = nutrition.vitaminB5 { lines.append("Vitamin B5: \(v) mg") }
        if let v = nutrition.vitaminB6 { lines.append("Vitamin B6: \(v) mg") }
        if let v = nutrition.vitaminB7 { lines.append("Vitamin B7: \(v) mcg") }
        if let v = nutrition.vitaminB12 { lines.append("Vitamin B12: \(v) mcg") }
        if let v = nutrition.folate { lines.append("Folate: \(v) mcg") }

        // Minerals
        lines.append("\n--- Minerals ---")
        if let v = nutrition.calcium { lines.append("Calcium: \(v) mg") }
        if let v = nutrition.iron { lines.append("Iron: \(v) mg") }
        if let v = nutrition.potassium { lines.append("Potassium: \(v) mg") }
        if let v = nutrition.magnesium { lines.append("Magnesium: \(v) mg") }
        if let v = nutrition.zinc { lines.append("Zinc: \(v) mg") }
        if let v = nutrition.phosphorus { lines.append("Phosphorus: \(v) mg") }
        if let v = nutrition.selenium { lines.append("Selenium: \(v) mcg") }
        if let v = nutrition.copper { lines.append("Copper: \(v) mg") }
        if let v = nutrition.manganese { lines.append("Manganese: \(v) mg") }
        if let v = nutrition.chromium { lines.append("Chromium: \(v) mcg") }
        if let v = nutrition.molybdenum { lines.append("Molybdenum: \(v) mcg") }
        if let v = nutrition.iodine { lines.append("Iodine: \(v) mcg") }
        if let v = nutrition.chloride { lines.append("Chloride: \(v) mg") }

        if let confidence = nutrition.confidence { lines.append("\nConfidence: \(Int(confidence * 100))%") }
        return lines.joined(separator: "\n")
    }

    // MARK: - Create Product
    private func createProduct() -> Product {
        let product = Product(
            name: name,
            barcode: barcode.isEmpty ? nil : barcode,
            brand: brand.isEmpty ? nil : brand,
            servingSize: 100,  // Always store per 100 units
            servingSizeUnit: "g",
            calories: Double(calories) ?? 0,
            protein: Double(protein) ?? 0,
            carbohydrates: Double(carbohydrates) ?? 0,
            fat: Double(fat) ?? 0,
            isCustom: true
        )

        // Portion info
        product.portionSize = Double(portionSize)
        product.portionsPerPackage = Int(portionsPerPackage)

        // Main nutrition
        product.saturatedFat = Double(saturatedFat)
        product.transFat = Double(transFat)
        product.fibre = Double(fibre)

        // Sugar: only Natural and Added, calculate total from both
        let naturalSugarValue = Double(naturalSugar) ?? 0
        let addedSugarValue = Double(addedSugar) ?? 0
        product.naturalSugar = naturalSugarValue > 0 ? naturalSugarValue : nil
        product.addedSugar = addedSugarValue > 0 ? addedSugarValue : nil
        product.sugar = (naturalSugarValue + addedSugarValue) > 0 ? (naturalSugarValue + addedSugarValue) : nil

        product.sodium = Double(sodium)
        product.cholesterol = Double(cholesterol)

        // Vitamins & Minerals - iterate over NutrientDefinitions
        for def in NutrientDefinitions.all {
            if let valueStr = nutrientValues[def.id], !valueStr.isEmpty {
                product.setNutrientValue(Double(valueStr), for: def.id)
            }
        }

        // Store captured image
        if let image = capturedImage {
            product.imageData = image.jpegData(compressionQuality: 0.7)
        }

        return product
    }

    // MARK: - AI Vitamin Estimation
    private func estimateVitaminsWithAI() async {
        guard !name.isEmpty else { return }

        isEstimatingVitamins = true
        defer { isEstimatingVitamins = false }

        let inputPrompt = "100g of \(name)"

        do {
            // Use the existing AI prompt to get nutrition estimate for the food name
            let estimate = try await aiManager.estimateFromPrompt(inputPrompt)

            // Log the successful AI response
            await MainActor.run {
                let logEntry = AILogEntry(
                    requestType: "vitamin_estimation",
                    provider: aiManager.selectedProvider.displayName,
                    input: inputPrompt,
                    output: formatVitaminEstimateForLog(estimate),
                    success: true
                )
                modelContext.insert(logEntry)
            }

            await MainActor.run {
                // Fill in vitamins & minerals from AI response using dictionary
                setNutrientFromAI(estimate.vitaminA, id: "vitaminA", decimals: 0)
                setNutrientFromAI(estimate.vitaminC, id: "vitaminC", decimals: 1)
                setNutrientFromAI(estimate.vitaminD, id: "vitaminD", decimals: 1)
                setNutrientFromAI(estimate.vitaminE, id: "vitaminE", decimals: 1)
                setNutrientFromAI(estimate.vitaminK, id: "vitaminK", decimals: 0)
                setNutrientFromAI(estimate.vitaminB1, id: "vitaminB1", decimals: 2)
                setNutrientFromAI(estimate.vitaminB2, id: "vitaminB2", decimals: 2)
                setNutrientFromAI(estimate.vitaminB3, id: "vitaminB3", decimals: 1)
                setNutrientFromAI(estimate.vitaminB5, id: "vitaminB5", decimals: 2)
                setNutrientFromAI(estimate.vitaminB6, id: "vitaminB6", decimals: 2)
                setNutrientFromAI(estimate.vitaminB7, id: "vitaminB7", decimals: 1)
                setNutrientFromAI(estimate.vitaminB12, id: "vitaminB12", decimals: 2)
                setNutrientFromAI(estimate.folate, id: "folate", decimals: 0)
                setNutrientFromAI(estimate.calcium, id: "calcium", decimals: 0)
                setNutrientFromAI(estimate.iron, id: "iron", decimals: 1)
                setNutrientFromAI(estimate.potassium, id: "potassium", decimals: 0)
                setNutrientFromAI(estimate.magnesium, id: "magnesium", decimals: 0)
                setNutrientFromAI(estimate.zinc, id: "zinc", decimals: 1)
                setNutrientFromAI(estimate.phosphorus, id: "phosphorus", decimals: 0)
                setNutrientFromAI(estimate.selenium, id: "selenium", decimals: 0)
                setNutrientFromAI(estimate.copper, id: "copper", decimals: 2)
                setNutrientFromAI(estimate.manganese, id: "manganese", decimals: 1)
                setNutrientFromAI(estimate.chromium, id: "chromium", decimals: 1)
                setNutrientFromAI(estimate.molybdenum, id: "molybdenum", decimals: 1)
                setNutrientFromAI(estimate.iodine, id: "iodine", decimals: 0)
                setNutrientFromAI(estimate.chloride, id: "chloride", decimals: 0)

                // Also fill in sugar/fibre/sodium if not already set
                if sugar.isEmpty, let s = estimate.sugar { sugar = String(format: "%.1f", s) }
                if fibre.isEmpty, let f = estimate.fibre { fibre = String(format: "%.1f", f) }
                if sodium.isEmpty, let sod = estimate.sodium { sodium = String(format: "%.0f", sod) }

                // Expand sections to show the filled data
                showingVitamins = true
                showingMinerals = true
            }
        } catch {
            // Log the failed AI response
            await MainActor.run {
                let logEntry = AILogEntry(
                    requestType: "vitamin_estimation",
                    provider: aiManager.selectedProvider.displayName,
                    input: inputPrompt,
                    output: "",
                    success: false,
                    errorMessage: error.localizedDescription
                )
                modelContext.insert(logEntry)

                errorMessage = "Failed to estimate vitamins: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    // Format vitamin estimate for AI log
    private func formatVitaminEstimateForLog(_ estimate: QuickFoodEstimate) -> String {
        var lines: [String] = []
        lines.append("Food: \(estimate.foodName)")
        lines.append("Amount: \(estimate.amount) \(estimate.unit)")
        lines.append("Weight: \(estimate.weightInGrams)g")
        lines.append("Calories: \(estimate.calories) kcal")

        lines.append("\n--- Vitamins ---")
        if let v = estimate.vitaminA { lines.append("Vitamin A: \(v) mcg") }
        if let v = estimate.vitaminC { lines.append("Vitamin C: \(v) mg") }
        if let v = estimate.vitaminD { lines.append("Vitamin D: \(v) mcg") }
        if let v = estimate.vitaminE { lines.append("Vitamin E: \(v) mg") }
        if let v = estimate.vitaminK { lines.append("Vitamin K: \(v) mcg") }
        if let v = estimate.vitaminB1 { lines.append("Vitamin B1: \(v) mg") }
        if let v = estimate.vitaminB2 { lines.append("Vitamin B2: \(v) mg") }
        if let v = estimate.vitaminB3 { lines.append("Vitamin B3: \(v) mg") }
        if let v = estimate.vitaminB5 { lines.append("Vitamin B5: \(v) mg") }
        if let v = estimate.vitaminB6 { lines.append("Vitamin B6: \(v) mg") }
        if let v = estimate.vitaminB7 { lines.append("Vitamin B7: \(v) mcg") }
        if let v = estimate.vitaminB12 { lines.append("Vitamin B12: \(v) mcg") }
        if let v = estimate.folate { lines.append("Folate: \(v) mcg") }

        lines.append("\n--- Minerals ---")
        if let v = estimate.calcium { lines.append("Calcium: \(v) mg") }
        if let v = estimate.iron { lines.append("Iron: \(v) mg") }
        if let v = estimate.potassium { lines.append("Potassium: \(v) mg") }
        if let v = estimate.magnesium { lines.append("Magnesium: \(v) mg") }
        if let v = estimate.zinc { lines.append("Zinc: \(v) mg") }
        if let v = estimate.phosphorus { lines.append("Phosphorus: \(v) mg") }
        if let v = estimate.selenium { lines.append("Selenium: \(v) mcg") }
        if let v = estimate.copper { lines.append("Copper: \(v) mg") }
        if let v = estimate.manganese { lines.append("Manganese: \(v) mg") }
        if let v = estimate.chromium { lines.append("Chromium: \(v) mcg") }
        if let v = estimate.molybdenum { lines.append("Molybdenum: \(v) mcg") }
        if let v = estimate.iodine { lines.append("Iodine: \(v) mcg") }
        if let v = estimate.chloride { lines.append("Chloride: \(v) mg") }

        lines.append("\nConfidence: \(Int(estimate.confidence * 100))%")
        if let notes = estimate.notes { lines.append("Notes: \(notes)") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Nutrition Scan View (simplified camera)
struct NutritionScanView: View {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    var body: some View {
        NavigationStack {
            NutritionCameraView { image in
                onCapture(image)
                dismiss()
            }
        }
    }
}

// MARK: - Nutrition Text Field
struct NutritionTextField: View {
    let label: String
    @Binding var value: String
    let unit: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
        }
    }
}

#Preview {
    ManualEntryView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self], inMemory: true)
}
