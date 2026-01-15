// AddFoodView.swift - Main food entry view with multiple input methods
// Made by mpcode

import SwiftUI
import SwiftData

// Helper struct for passing barcode to sheet
struct BarcodeItem: Identifiable {
    let id = UUID()
    let barcode: String
}

struct AddFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var aiManager = AIServiceManager.shared
    @State private var showingScanner = false
    @State private var showingCamera = false
    @State private var showingManualEntryWithoutBarcode = false
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

    // Barcode for manual entry - using Identifiable for reliable sheet binding
    @State private var scannedBarcodeForManualEntry = ""
    @State private var scannedBarcodeBinding: BarcodeItem?

    // Product search and log sheet
    @State private var searchText = ""
    @State private var showingProductSearch = false
    @State private var selectedProductForLog: Product?

    @Query private var todayLogs: [DailyLog]
    @Query(sort: \Product.dateAdded, order: .reverse) private var allProducts: [Product]
    @Query(sort: \AIFoodTemplate.lastUsed, order: .reverse)
    private var aiTemplates: [AIFoodTemplate]

    private var recentProducts: [Product] {
        // Only show products that were added via barcode (not AI-generated)
        let barcodeProducts = allProducts.filter { $0.barcode != nil && !$0.barcode!.isEmpty }
        return Array(barcodeProducts.prefix(10))
    }

    // Only show barcode-scanned products (not AI-generated)
    private var barcodeProducts: [Product] {
        allProducts.filter { $0.barcode != nil && !$0.barcode!.isEmpty }
    }

    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return barcodeProducts
        }
        return barcodeProducts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.brand?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.barcode?.contains(searchText) ?? false)
        }
    }

    private var todayLog: DailyLog? {
        todayLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic animated background
                AppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Quick AI input section
                        quickInputSection

                        // Action buttons
                        actionButtonsSection

                        // AI Foods (previously logged)
                        if !aiTemplates.isEmpty {
                            aiFoodsSection
                        }

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
            .sheet(item: $scannedBarcodeBinding, onDismiss: {
                scannedBarcodeForManualEntry = ""
            }) { barcodeItem in
                ManualEntryView(initialBarcode: barcodeItem.barcode)
            }
            .sheet(isPresented: $showingManualEntryWithoutBarcode) {
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
            .sheet(item: $selectedProductForLog) { product in
                AddProductToLogSheet(product: product)
            }
            .sheet(isPresented: $showingProductSearch) {
                ProductSearchSheet(
                    products: filteredProducts,
                    searchText: $searchText,
                    onSelect: { product in
                        showingProductSearch = false
                        // Delay to avoid sheet presentation conflict
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedProductForLog = product
                        }
                    },
                    onDelete: { product in
                        deleteProduct(product)
                    }
                )
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Quick Add with AI")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            HStack(spacing: 12) {
                TextField("e.g., \"I had one apple\"", text: $quickInputText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(isProcessingAI)

                Button {
                    Task {
                        await processQuickInput()
                    }
                } label: {
                    if isProcessingAI {
                        ProgressView()
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                .disabled(quickInputText.isEmpty || isProcessingAI)
            }

            Text("Describe what you ate and AI will estimate the calories")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.purple.opacity(0.1)), in: RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 8)
            }
        }
    }

    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            ModernActionButton(
                title: "Scan Barcode",
                icon: "barcode.viewfinder",
                gradientColors: [.blue, .blue.opacity(0.8)]
            ) {
                showingScanner = true
            }

            ModernActionButton(
                title: "Manual Entry",
                icon: "square.and.pencil",
                gradientColors: [.orange, .orange.opacity(0.8)]
            ) {
                showingManualEntryWithoutBarcode = true
            }
        }
    }

    private var aiFoodsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                Text("Quick Add (AI Foods)")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Text("Tap to add")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Grid layout instead of horizontal scroll
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(aiTemplates) { template in
                    AIFoodTemplateChip(
                        template: template,
                        onTap: { quickAddAIFood(template) },
                        onDelete: { deleteAITemplate(template) }
                    )
                }
            }
        }
        .padding(20)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.purple.opacity(0.1)), in: RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 8)
            }
        }
    }

    private func deleteAITemplate(_ template: AIFoodTemplate) {
        modelContext.delete(template)
    }

    private func quickAddAIFood(_ template: AIFoodTemplate) {
        // Check if this food already exists in today's log
        let foodName = template.name

        if let existingEntry = findExistingEntry(named: foodName) {
            // Increment existing entry
            let addAmount = template.amount
            existingEntry.adjustAmount(by: addAmount)
            template.recordUse()
            showSuccessFeedback(food: "\(Int(existingEntry.amount))\(existingEntry.unit) \(foodName)", calories: Int(existingEntry.calories))
        } else {
            // Check if a Product with this name already exists (from a previous Quick Add)
            let existingProduct = allProducts.first { $0.name.lowercased() == foodName.lowercased() && $0.barcode == nil }

            if let product = existingProduct {
                // Reuse existing product, just create a new entry
                let entry = FoodEntry(
                    product: product,
                    amount: template.amount,
                    unit: template.unit,
                    calories: template.calories,
                    protein: template.protein,
                    carbohydrates: template.carbohydrates,
                    fat: template.fat,
                    sugar: template.sugar,
                    naturalSugar: template.naturalSugar,
                    addedSugar: template.addedSugar,
                    fibre: template.fibre,
                    sodium: template.sodium,
                    aiGenerated: true,
                    aiPrompt: template.aiPrompt
                )
                addEntryToTodayLog(entry)
                template.recordUse()
                showSuccessFeedback(food: entry.displayName, calories: Int(entry.calories))
            } else {
                // Create new Product with vitamins and link FoodEntry to it
                let (entry, product) = template.createEntryWithProduct()

                modelContext.insert(product)
                addEntryToTodayLog(entry)
                template.recordUse()
                showSuccessFeedback(food: entry.displayName, calories: Int(entry.calories))
            }
        }
    }

    private func findExistingEntry(named foodName: String) -> FoodEntry? {
        guard let entries = todayLog?.entries else { return nil }

        return entries.first { entry in
            let entryName = entry.customFoodName ?? entry.displayName
            return entryName.lowercased() == foodName.lowercased() && entry.aiGenerated
        }
    }

    private var recentProductsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Products")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                if !allProducts.isEmpty {
                    Button {
                        showingProductSearch = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                            Text("Browse All")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }

            if recentProducts.isEmpty {
                ContentUnavailableView {
                    Label("No products yet", systemImage: "cart")
                } description: {
                    Text("Scan a barcode or add a product manually")
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(recentProducts.prefix(5)) { product in
                        RecentProductRow(product: product) {
                            selectedProductForLog = product
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteProduct(product)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
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

    private func deleteProduct(_ product: Product) {
        modelContext.delete(product)
    }

    // MARK: - Actions
    private func processQuickInput() async {
        guard !quickInputText.isEmpty else { return }
        let inputText = quickInputText

        isProcessingAI = true
        defer { isProcessingAI = false }

        do {
            let estimate = try await aiManager.estimateFromPrompt(inputText)

            // Log the successful AI response
            let logEntry = AILogEntry(
                requestType: "food_estimate",
                provider: aiManager.selectedProvider.displayName,
                input: inputText,
                output: formatFoodEstimateForLog(estimate),
                success: true
            )
            modelContext.insert(logEntry)

            // Check if this food already exists in today's log
            if let existingEntry = findExistingEntry(named: estimate.foodName) {
                // Increment existing entry
                existingEntry.adjustAmount(by: estimate.amount)
                quickInputText = ""
                showSuccessFeedback(food: "\(Int(existingEntry.amount))\(existingEntry.unit) \(estimate.foodName)", calories: Int(existingEntry.calories))
            } else {
                // Create template from estimate (captures vitamins)
                let template = AIFoodTemplate(from: estimate, prompt: inputText)

                // Create Product with vitamins and link FoodEntry to it
                let (entry, product) = template.createEntryWithProduct()

                // Insert product and entry
                modelContext.insert(product)
                addEntryToTodayLog(entry)

                // Save template for quick add (if not already exists)
                saveAsTemplate(template)

                quickInputText = ""
                showSuccessFeedback(food: estimate.foodName, calories: Int(estimate.calories))
            }
        } catch {
            // Log the failed AI response
            let logEntry = AILogEntry(
                requestType: "food_estimate",
                provider: aiManager.selectedProvider.displayName,
                input: inputText,
                output: "",
                success: false,
                errorMessage: error.localizedDescription
            )
            modelContext.insert(logEntry)

            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func formatFoodEstimateForLog(_ estimate: QuickFoodEstimate) -> String {
        var lines: [String] = []
        lines.append("Food: \(estimate.foodName)")
        lines.append("Amount: \(estimate.amount) \(estimate.unit)")
        lines.append("Calories: \(estimate.calories) kcal")
        lines.append("Protein: \(estimate.protein)g")
        lines.append("Carbs: \(estimate.carbohydrates)g")
        lines.append("Fat: \(estimate.fat)g")
        if let sugar = estimate.sugar { lines.append("Sugar: \(sugar)g") }
        if let naturalSugar = estimate.naturalSugar { lines.append("  Natural Sugar: \(naturalSugar)g") }
        if let addedSugar = estimate.addedSugar { lines.append("  Added Sugar: \(addedSugar)g") }
        if let fibre = estimate.fibre { lines.append("Fibre: \(fibre)g") }
        if let sodium = estimate.sodium { lines.append("Sodium: \(sodium)mg") }

        // Vitamins
        lines.append("\n--- Vitamins ---")
        if let v = estimate.vitaminA { lines.append("Vitamin A: \(v) mcg") }
        if let v = estimate.vitaminC { lines.append("Vitamin C: \(v) mg") }
        if let v = estimate.vitaminD { lines.append("Vitamin D: \(v) mcg") }
        if let v = estimate.vitaminE { lines.append("Vitamin E: \(v) mg") }
        if let v = estimate.vitaminK { lines.append("Vitamin K: \(v) mcg") }
        if let v = estimate.vitaminB1 { lines.append("Vitamin B1: \(v) mg") }
        if let v = estimate.vitaminB2 { lines.append("Vitamin B2: \(v) mg") }
        if let v = estimate.vitaminB3 { lines.append("Vitamin B3: \(v) mg") }
        if let v = estimate.vitaminB6 { lines.append("Vitamin B6: \(v) mg") }
        if let v = estimate.vitaminB12 { lines.append("Vitamin B12: \(v) mcg") }
        if let v = estimate.folate { lines.append("Folate: \(v) mcg") }

        // Minerals
        lines.append("\n--- Minerals ---")
        if let v = estimate.calcium { lines.append("Calcium: \(v) mg") }
        if let v = estimate.iron { lines.append("Iron: \(v) mg") }
        if let v = estimate.zinc { lines.append("Zinc: \(v) mg") }
        if let v = estimate.magnesium { lines.append("Magnesium: \(v) mg") }
        if let v = estimate.potassium { lines.append("Potassium: \(v) mg") }
        if let v = estimate.phosphorus { lines.append("Phosphorus: \(v) mg") }
        if let v = estimate.selenium { lines.append("Selenium: \(v) mcg") }
        if let v = estimate.copper { lines.append("Copper: \(v) mg") }
        if let v = estimate.manganese { lines.append("Manganese: \(v) mg") }

        lines.append("\nConfidence: \(Int(estimate.confidence * 100))%")
        if let notes = estimate.notes { lines.append("Notes: \(notes)") }
        return lines.joined(separator: "\n")
    }

    /// Save template for quick add (if not already exists)
    private func saveAsTemplate(_ template: AIFoodTemplate) {
        // Check if template already exists
        let existingTemplate = aiTemplates.first { $0.name.lowercased() == template.name.lowercased() }
        if existingTemplate != nil {
            return // Template already exists
        }

        // Insert new template
        modelContext.insert(template)
    }

    private func processNutritionImage(_ image: UIImage) async {
        isProcessingAI = true
        defer { isProcessingAI = false }

        do {
            let nutrition = try await aiManager.parseNutritionLabel(image: image)

            // Log the successful AI response
            let logEntry = AILogEntry(
                requestType: "nutrition_label",
                provider: aiManager.selectedProvider.displayName,
                input: "[Image scan]",
                output: formatNutritionLabelForLog(nutrition),
                success: true
            )
            modelContext.insert(logEntry)

            // Store for confirmation instead of adding directly
            await MainActor.run {
                pendingNutrition = nutrition
                pendingImage = image
                showingNutritionConfirmation = true
            }
        } catch {
            // Log the failed AI response
            let logEntry = AILogEntry(
                requestType: "nutrition_label",
                provider: aiManager.selectedProvider.displayName,
                input: "[Image scan]",
                output: "",
                success: false,
                errorMessage: error.localizedDescription
            )
            modelContext.insert(logEntry)

            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func formatNutritionLabelForLog(_ nutrition: ParsedNutrition) -> String {
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
        if let confidence = nutrition.confidence { lines.append("Confidence: \(Int(confidence * 100))%") }
        return lines.joined(separator: "\n")
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
        let barcodeToFind = barcode
        let descriptor = FetchDescriptor<Product>(
            predicate: #Predicate { $0.barcode == barcodeToFind }
        )

        if let existingProduct = try? modelContext.fetch(descriptor).first {
            // Show log sheet for existing product
            selectedProductForLog = existingProduct
        } else {
            // Show manual entry with barcode pre-filled using item binding for reliability
            scannedBarcodeBinding = BarcodeItem(barcode: barcode)
        }
    }

    private func addProductEntry(_ product: Product) {
        // Scale nutrition values from per 100g to serving size
        let scale = product.servingSize / 100.0
        let entry = FoodEntry(
            product: product,
            amount: product.servingSize,
            unit: product.servingSizeUnit,
            calories: product.calories * scale,
            protein: product.protein * scale,
            carbohydrates: product.carbohydrates * scale,
            fat: product.fat * scale,
            sugar: (product.sugar ?? 0) * scale,
            naturalSugar: (product.naturalSugar ?? 0) * scale,
            addedSugar: (product.addedSugar ?? 0) * scale,
            fibre: (product.fibre ?? 0) * scale,
            sodium: (product.sodium ?? 0) * scale
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
                            naturalSugar: nutrition.naturalSugar,
                            addedSugar: nutrition.addedSugar,
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

// MARK: - Modern Action Button
struct ModernActionButton: View {
    let title: String
    let icon: String
    let gradientColors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: gradientColors[0].opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Recent Product Row
struct RecentProductRow: View {
    let product: Product
    let onTap: () -> Void

    // Use centralised utilities for emoji and image
    private var foodEmoji: String {
        product.displayEmoji
    }

    private var displayImage: UIImage? {
        product.displayImage
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                // Product image or emoji (prefer main photo)
                if let uiImage = displayImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Show emoji based on name matching
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Text(foodEmoji)
                                .font(.title2)
                        }
                }

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

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(product.calories)) kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Show per 100g or per portion
                    if let portionCals = product.caloriesPerPortion {
                        Text("\(Int(portionCals))/portion")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    } else {
                        Text("per 100g")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Product Search Sheet
struct ProductSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let products: [Product]
    @Binding var searchText: String
    let onSelect: (Product) -> Void
    let onDelete: (Product) -> Void

    var body: some View {
        NavigationStack {
            List {
                if products.isEmpty {
                    ContentUnavailableView {
                        Label("No products found", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try a different search term or add a new product")
                    }
                } else {
                    ForEach(products) { product in
                        Button {
                            onSelect(product)
                        } label: {
                            ProductSearchRow(product: product)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onDelete(product)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Products")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search products")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Product Search Row
struct ProductSearchRow: View {
    let product: Product

    // Use centralised utilities for emoji and image
    private var foodEmoji: String {
        product.displayEmoji
    }

    private var displayImage: UIImage? {
        product.displayImage
    }

    var body: some View {
        HStack(spacing: 12) {
            // Product image or emoji (prefer main photo)
            if let uiImage = displayImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(foodEmoji)
                            .font(.title)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    if let brand = product.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if product.barcode != nil {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Image(systemName: "barcode")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(product.calories)) kcal")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("per 100g")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AI Food Template Chip
struct AIFoodTemplateChip: View {
    let template: AIFoodTemplate
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)

                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    Text("\(Int(template.calories)) kcal")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(Int(template.amount)) \(template.unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.gray)
                        .background(Circle().fill(.white))
                }
                .offset(x: 6, y: -6)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddFoodView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self, AIFoodTemplate.self, AILogEntry.self], inMemory: true)
}
