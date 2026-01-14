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

    @Query private var todayLogs: [DailyLog]
    @Query(sort: \Product.dateAdded, order: .reverse) private var recentProducts: [Product]

    private var todayLog: DailyLog? {
        todayLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
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
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
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

        isProcessingAI = true
        defer { isProcessingAI = false }

        do {
            let estimate = try await claudeService.estimateFromPrompt(quickInputText)

            let entry = FoodEntry(
                customFoodName: estimate.foodName,
                amount: estimate.amount,
                unit: estimate.unit,
                calories: estimate.calories,
                protein: estimate.protein,
                carbohydrates: estimate.carbohydrates,
                fat: estimate.fat,
                aiGenerated: true,
                aiPrompt: quickInputText
            )

            addEntryToTodayLog(entry)
            quickInputText = ""
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
            product.imageData = image.jpegData(compressionQuality: 0.7)

            modelContext.insert(product)
            addProductEntry(product)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func handleScannedBarcode(_ barcode: String) {
        // Check if product exists
        let descriptor = FetchDescriptor<Product>(
            predicate: #Predicate { $0.barcode == barcode }
        )

        if let existingProduct = try? modelContext.fetch(descriptor).first {
            addProductEntry(existingProduct)
        } else {
            // Show manual entry with barcode pre-filled
            // For now, create placeholder
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
