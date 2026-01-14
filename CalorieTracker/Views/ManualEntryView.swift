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
    @State private var servingSizeUnit = "g"

    // Main nutrition
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbohydrates = ""
    @State private var fat = ""
    @State private var saturatedFat = ""
    @State private var transFat = ""
    @State private var fibre = ""
    @State private var sugar = ""
    @State private var sodium = ""
    @State private var cholesterol = ""

    // Vitamins
    @State private var vitaminA = ""
    @State private var vitaminC = ""
    @State private var vitaminD = ""
    @State private var vitaminE = ""
    @State private var vitaminK = ""
    @State private var vitaminB1 = ""
    @State private var vitaminB2 = ""
    @State private var vitaminB3 = ""
    @State private var vitaminB6 = ""
    @State private var vitaminB12 = ""
    @State private var folate = ""

    // Minerals
    @State private var calcium = ""
    @State private var iron = ""
    @State private var potassium = ""
    @State private var magnesium = ""
    @State private var zinc = ""
    @State private var phosphorus = ""
    @State private var selenium = ""
    @State private var copper = ""
    @State private var manganese = ""

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
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var capturedImage: UIImage?

    // Duplicate detection
    @State private var existingProduct: Product?
    @State private var showingDuplicateAlert = false

    // Show log sheet after save - using Identifiable wrapper for reliable sheet binding
    @State private var productToLog: ProductItem?

    var isValid: Bool {
        !name.isEmpty && !calories.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
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

                // Main nutrition (per 100g)
                Section {
                    DisclosureGroup("Main Nutrition (per 100g)", isExpanded: $showingMainNutrition) {
                        NutritionTextField(label: "Calories *", value: $calories, unit: "kcal")
                        NutritionTextField(label: "Protein", value: $protein, unit: "g")
                        NutritionTextField(label: "Carbohydrates", value: $carbohydrates, unit: "g")
                        NutritionTextField(label: "Fat", value: $fat, unit: "g")
                        NutritionTextField(label: "Saturated Fat", value: $saturatedFat, unit: "g")
                        NutritionTextField(label: "Trans Fat", value: $transFat, unit: "g")
                        NutritionTextField(label: "Fibre", value: $fibre, unit: "g")
                        NutritionTextField(label: "Sugar", value: $sugar, unit: "g")
                        NutritionTextField(label: "Sodium (Salt)", value: $sodium, unit: "mg")
                        NutritionTextField(label: "Cholesterol", value: $cholesterol, unit: "mg")
                    }
                }

                // Vitamins (per 100g)
                Section {
                    DisclosureGroup("Vitamins (per 100g)", isExpanded: $showingVitamins) {
                        NutritionTextField(label: "Vitamin A", value: $vitaminA, unit: "%")
                        NutritionTextField(label: "Vitamin C", value: $vitaminC, unit: "%")
                        NutritionTextField(label: "Vitamin D", value: $vitaminD, unit: "%")
                        NutritionTextField(label: "Vitamin E", value: $vitaminE, unit: "%")
                        NutritionTextField(label: "Vitamin K", value: $vitaminK, unit: "%")
                        NutritionTextField(label: "Thiamin (B1)", value: $vitaminB1, unit: "%")
                        NutritionTextField(label: "Riboflavin (B2)", value: $vitaminB2, unit: "%")
                        NutritionTextField(label: "Niacin (B3)", value: $vitaminB3, unit: "%")
                        NutritionTextField(label: "Vitamin B6", value: $vitaminB6, unit: "%")
                        NutritionTextField(label: "Vitamin B12", value: $vitaminB12, unit: "%")
                        NutritionTextField(label: "Folate", value: $folate, unit: "%")
                    }
                }

                // Minerals (per 100g)
                Section {
                    DisclosureGroup("Minerals (per 100g)", isExpanded: $showingMinerals) {
                        NutritionTextField(label: "Calcium", value: $calcium, unit: "mg")
                        NutritionTextField(label: "Iron", value: $iron, unit: "mg")
                        NutritionTextField(label: "Potassium", value: $potassium, unit: "mg")
                        NutritionTextField(label: "Magnesium", value: $magnesium, unit: "mg")
                        NutritionTextField(label: "Zinc", value: $zinc, unit: "mg")
                        NutritionTextField(label: "Phosphorus", value: $phosphorus, unit: "mg")
                        NutritionTextField(label: "Selenium", value: $selenium, unit: "mcg")
                        NutritionTextField(label: "Copper", value: $copper, unit: "mg")
                        NutritionTextField(label: "Manganese", value: $manganese, unit: "mg")
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
        existing.sugar = Double(sugar)
        existing.sodium = Double(sodium)
        existing.cholesterol = Double(cholesterol)

        // Vitamins
        existing.vitaminA = Double(vitaminA)
        existing.vitaminC = Double(vitaminC)
        existing.vitaminD = Double(vitaminD)
        existing.vitaminE = Double(vitaminE)
        existing.vitaminK = Double(vitaminK)
        existing.vitaminB1 = Double(vitaminB1)
        existing.vitaminB2 = Double(vitaminB2)
        existing.vitaminB3 = Double(vitaminB3)
        existing.vitaminB6 = Double(vitaminB6)
        existing.vitaminB12 = Double(vitaminB12)
        existing.folate = Double(folate)

        // Minerals
        existing.calcium = Double(calcium)
        existing.iron = Double(iron)
        existing.potassium = Double(potassium)
        existing.magnesium = Double(magnesium)
        existing.zinc = Double(zinc)
        existing.phosphorus = Double(phosphorus)
        existing.selenium = Double(selenium)
        existing.copper = Double(copper)
        existing.manganese = Double(manganese)

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

            await MainActor.run {
                // Auto-fill all fields from AI response
                if let productName = nutrition.productName { name = productName }
                if let size = nutrition.servingSize { servingSize = String(Int(size)) }
                if let unit = nutrition.servingSizeUnit { servingSizeUnit = unit }

                calories = String(Int(nutrition.calories))
                if let p = nutrition.protein { protein = String(format: "%.1f", p) }
                if let c = nutrition.carbohydrates { carbohydrates = String(format: "%.1f", c) }
                if let f = nutrition.fat { fat = String(format: "%.1f", f) }
                if let sf = nutrition.saturatedFat { saturatedFat = String(format: "%.1f", sf) }
                if let tf = nutrition.transFat { transFat = String(format: "%.1f", tf) }
                if let fb = nutrition.fibre { fibre = String(format: "%.1f", fb) }
                if let s = nutrition.sugar { sugar = String(format: "%.1f", s) }
                if let sod = nutrition.sodium { sodium = String(Int(sod)) }
                if let ch = nutrition.cholesterol { cholesterol = String(Int(ch)) }

                // Vitamins
                if let va = nutrition.vitaminA { vitaminA = String(Int(va)) }
                if let vc = nutrition.vitaminC { vitaminC = String(Int(vc)) }
                if let vd = nutrition.vitaminD { vitaminD = String(Int(vd)) }
                if let ve = nutrition.vitaminE { vitaminE = String(Int(ve)) }
                if let vk = nutrition.vitaminK { vitaminK = String(Int(vk)) }
                if let b1 = nutrition.vitaminB1 { vitaminB1 = String(Int(b1)) }
                if let b2 = nutrition.vitaminB2 { vitaminB2 = String(Int(b2)) }
                if let b3 = nutrition.vitaminB3 { vitaminB3 = String(Int(b3)) }
                if let b6 = nutrition.vitaminB6 { vitaminB6 = String(Int(b6)) }
                if let b12 = nutrition.vitaminB12 { vitaminB12 = String(Int(b12)) }
                if let fo = nutrition.folate { folate = String(Int(fo)) }

                // Minerals
                if let ca = nutrition.calcium { calcium = String(Int(ca)) }
                if let fe = nutrition.iron { iron = String(format: "%.1f", fe) }
                if let k = nutrition.potassium { potassium = String(Int(k)) }
                if let mg = nutrition.magnesium { magnesium = String(Int(mg)) }
                if let zn = nutrition.zinc { zinc = String(format: "%.1f", zn) }
                if let ph = nutrition.phosphorus { phosphorus = String(Int(ph)) }
                if let se = nutrition.selenium { selenium = String(Int(se)) }
                if let cu = nutrition.copper { copper = String(format: "%.2f", cu) }
                if let mn = nutrition.manganese { manganese = String(format: "%.1f", mn) }

                // Expand sections that have data
                showingVitamins = !vitaminA.isEmpty || !vitaminC.isEmpty || !vitaminD.isEmpty
                showingMinerals = !calcium.isEmpty || !iron.isEmpty || !potassium.isEmpty
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    // MARK: - Create Product
    private func createProduct() -> Product {
        let product = Product(
            name: name,
            barcode: barcode.isEmpty ? nil : barcode,
            brand: brand.isEmpty ? nil : brand,
            servingSize: 100,  // Always store per 100g
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
        product.sugar = Double(sugar)
        product.sodium = Double(sodium)
        product.cholesterol = Double(cholesterol)

        // Vitamins
        product.vitaminA = Double(vitaminA)
        product.vitaminC = Double(vitaminC)
        product.vitaminD = Double(vitaminD)
        product.vitaminE = Double(vitaminE)
        product.vitaminK = Double(vitaminK)
        product.vitaminB1 = Double(vitaminB1)
        product.vitaminB2 = Double(vitaminB2)
        product.vitaminB3 = Double(vitaminB3)
        product.vitaminB6 = Double(vitaminB6)
        product.vitaminB12 = Double(vitaminB12)
        product.folate = Double(folate)

        // Minerals
        product.calcium = Double(calcium)
        product.iron = Double(iron)
        product.potassium = Double(potassium)
        product.magnesium = Double(magnesium)
        product.zinc = Double(zinc)
        product.phosphorus = Double(phosphorus)
        product.selenium = Double(selenium)
        product.copper = Double(copper)
        product.manganese = Double(manganese)

        // Store captured image
        if let image = capturedImage {
            product.imageData = image.jpegData(compressionQuality: 0.7)
        }

        return product
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
