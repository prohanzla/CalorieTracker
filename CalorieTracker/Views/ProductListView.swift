// ProductListView.swift - List of all saved products
// Made by mpcode

import SwiftUI
import SwiftData
import TipKit
import UIKit

struct ProductListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Product.name) private var allProducts: [Product]

    // Tip - stored instance for proper dismissal tracking
    @State private var productSearchTip = ProductSearchTip()

    @State private var searchText = ""
    @State private var selectedProduct: Product?
    @State private var showingDeleteConfirmation = false
    @State private var productToDelete: Product?

    // Only show products with barcodes (not AI-generated)
    private var barcodeProducts: [Product] {
        allProducts.filter { $0.barcode != nil && !$0.barcode!.isEmpty }
    }

    var filteredProducts: [Product] {
        if searchText.isEmpty {
            return barcodeProducts
        }
        return barcodeProducts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.brand?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.barcode?.contains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic animated background
                AppBackground()

                // DEBUG: View identifier badge
                VStack {
                    HStack {
                        Text("V3")
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
                .padding(.top, 50)
                .padding(.leading, 8)

                Group {
                if barcodeProducts.isEmpty {
                    ContentUnavailableView {
                        Label("No Products", systemImage: "cart")
                    } description: {
                        Text("Scan a barcode or add products manually to build your database.")
                    }
                } else {
                    List {
                        // Inline tip for product search
                        TipView(productSearchTip)
                            .listRowBackground(Color.clear)
                            .onTapGesture {
                                productSearchTip.invalidate(reason: .actionPerformed)
                            }

                        ForEach(filteredProducts) { product in
                            ProductRow(product: product)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedProduct = product
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        productToDelete = product
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search products")
                    .scrollContentBackground(.hidden)
                    .onChange(of: searchText) { _, newValue in
                        if !newValue.isEmpty {
                            productSearchTip.invalidate(reason: .actionPerformed)
                        }
                    }
                }
            }
            } // Close ZStack
            .navigationTitle("Products")
            .sheet(item: $selectedProduct) { product in
                ProductDetailView(product: product)
            }
            .confirmationDialog(
                "Delete Product",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let product = productToDelete {
                        deleteProduct(product)
                    }
                }
                Button("Cancel", role: .cancel) {
                    productToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this product? This cannot be undone.")
            }
        }
    }

    private func deleteProduct(_ product: Product) {
        modelContext.delete(product)
        productToDelete = nil
    }
}

// MARK: - Product Row
struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            // Product image - prefer main photo, then nutrition label, then placeholder
            Group {
                if let mainData = product.mainImageData,
                   let uiImage = UIImage(data: mainData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if let imageData = product.imageData,
                          let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "cart.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 50, height: 50)
            .clipped()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let brand = product.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let barcode = product.barcode {
                        Label(barcode, systemImage: "barcode")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(product.calories))")
                    .font(.headline)
                Text("kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Product Detail View
struct ProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var product: Product

    @State private var showingCamera = false
    @State private var photoType: PhotoType = .main
    @State private var showingDeleteMainPhoto = false
    @State private var showingDeleteNutritionPhoto = false
    @State private var showingAddToToday = false
    @State private var addAmount: Double = 100
    @State private var showingAddSuccess = false
    @State private var isEditing = false

    // Edit mode state - stored as strings for TextField binding
    @State private var editName: String = ""
    @State private var editBrand: String = ""
    @State private var editCalories: String = ""
    @State private var editProtein: String = ""
    @State private var editCarbs: String = ""
    @State private var editFat: String = ""
    @State private var editSaturatedFat: String = ""
    @State private var editFibre: String = ""
    @State private var editNaturalSugar: String = ""
    @State private var editAddedSugar: String = ""
    @State private var editSodium: String = ""

    // Vitamin/mineral edit values - dictionary with nutrient ID as key
    @State private var editNutrients: [String: String] = [:]

    @FocusState private var focusedField: String?

    // Access to shared date manager for adding entries to correct date
    private var dateManager: SelectedDateManager { SelectedDateManager.shared }

    enum PhotoType {
        case main
        case nutrition
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // DEBUG: View identifier badge
                    HStack {
                        Text("V15")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.red))
                        Text("ProductDetailView")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    // Photos section
                    photosSection

                    // Basic info section
                    if isEditing {
                        editableBasicInfoSection
                    } else {
                        VStack(spacing: 8) {
                            Text(product.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            if let brand = product.brand {
                                Text(brand)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let barcode = product.barcode {
                                Label(barcode, systemImage: "barcode")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    // Nutrition per serving
                    if isEditing {
                        editableNutritionSection
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Nutrition Facts")
                                    .font(.headline)
                                Spacer()
                                Text("Per \(Int(product.servingSize))\(product.servingSizeUnit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Main macros
                            NutritionRow(label: "Calories", value: product.calories, unit: "kcal", isHighlighted: true)
                            NutritionRow(label: "Protein", value: product.protein, unit: "g")
                            NutritionRow(label: "Carbohydrates", value: product.carbohydrates, unit: "g")
                            NutritionRow(label: "Fat", value: product.fat, unit: "g")

                            // Optional values
                            if let saturatedFat = product.saturatedFat {
                                NutritionRow(label: "Saturated Fat", value: saturatedFat, unit: "g")
                            }
                            if let fibre = product.fibre {
                                NutritionRow(label: "Fibre", value: fibre, unit: "g")
                            }
                            if let naturalSugar = product.naturalSugar {
                                NutritionRow(label: "Natural Sugar", value: naturalSugar, unit: "g")
                            }
                            if let addedSugar = product.addedSugar {
                                NutritionRow(label: "Added Sugar", value: addedSugar, unit: "g")
                            }
                            if let sodium = product.sodium {
                                NutritionRow(label: "Sodium", value: sodium, unit: "mg")
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Vitamins & Minerals (if available) - uses centralized NutrientDefinitions
                    if isEditing {
                        editableVitaminsMineralsSection
                    } else if hasVitaminsOrMinerals {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Vitamins & Minerals")
                                .font(.headline)

                            // Vitamins - iterates over NutrientDefinitions
                            ForEach(NutrientDefinitions.vitamins) { def in
                                if let value = product.nutrientValue(for: def.id) {
                                    NutritionRow(label: def.name, value: value, unit: def.unit)
                                }
                            }

                            // Minerals - iterates over NutrientDefinitions
                            ForEach(NutrientDefinitions.minerals) { def in
                                if let value = product.nutrientValue(for: def.id) {
                                    NutritionRow(label: def.name, value: value, unit: def.unit)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Product" : "Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("Cancel") {
                            isEditing = false
                        }
                    } else {
                        Button {
                            addAmount = product.servingSize
                            showingAddToToday = true
                        } label: {
                            Label("Add to Today", systemImage: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                            isEditing = false
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Edit") {
                            loadEditValues()
                            isEditing = true
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !isEditing {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                ProductPhotoPickerSheet { image in
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        switch photoType {
                        case .main:
                            product.mainImageData = data
                        case .nutrition:
                            product.imageData = data
                        }
                    }
                }
            }
            .confirmationDialog("Delete Main Photo?", isPresented: $showingDeleteMainPhoto) {
                Button("Delete", role: .destructive) {
                    product.mainImageData = nil
                }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog("Delete Nutrition Photo?", isPresented: $showingDeleteNutritionPhoto) {
                Button("Delete", role: .destructive) {
                    product.imageData = nil
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingAddToToday) {
                AddProductToTodaySheet(
                    product: product,
                    amount: $addAmount,
                    onAdd: { addProductToToday() }
                )
                .presentationDetents([.medium])
            }
            .alert("Added to Today", isPresented: $showingAddSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("\(Int(addAmount))\(product.servingSizeUnit) of \(product.name) added to your food log.")
            }
        }
    }

    // MARK: - Add to Today
    private func addProductToToday() {
        // Calculate nutrition based on amount (product stores per 100g)
        let scale = addAmount / 100.0

        let entry = FoodEntry(
            product: product,
            amount: addAmount,
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

        // Find or create log for selected date
        let selectedDate = dateManager.selectedDate
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { log in
                log.date >= startOfDay && log.date < endOfDay
            }
        )

        if let existingLog = try? modelContext.fetch(descriptor).first {
            entry.dailyLog = existingLog
            modelContext.insert(entry)
        } else {
            let newLog = DailyLog(date: selectedDate)
            modelContext.insert(newLog)
            entry.dailyLog = newLog
            modelContext.insert(entry)
        }

        showingAddToToday = false
        showingAddSuccess = true
    }

    // MARK: - Photos Section
    private var photosSection: some View {
        VStack(spacing: 16) {
            Text("Photos")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                // Main product photo
                photoCard(
                    title: "Product",
                    imageData: product.mainImageData,
                    isMain: true,
                    onAdd: {
                        photoType = .main
                        showingCamera = true
                    },
                    onDelete: {
                        showingDeleteMainPhoto = true
                    }
                )

                // Nutrition label photo
                photoCard(
                    title: "Nutrition",
                    imageData: product.imageData,
                    isMain: false,
                    onAdd: {
                        photoType = .nutrition
                        showingCamera = true
                    },
                    onDelete: {
                        showingDeleteNutritionPhoto = true
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func photoCard(title: String, imageData: Data?, isMain: Bool, onAdd: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let data = imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipped()  // Clip overflow to prevent touch area extending beyond frame
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())  // Limit hit area to frame
                        .allowsHitTesting(false)  // Prevent image from blocking adjacent buttons

                    // Delete button
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, .red)
                            .shadow(radius: 2)
                    }
                    .offset(x: 8, y: -8)
                } else {
                    // Add photo placeholder
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                        Text("Add Photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 140, height: 140)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onAdd()
                    }
                }
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if isMain && imageData != nil {
                Label("Shown in lists", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
    }

    private var hasVitaminsOrMinerals: Bool {
        // Uses centralized NutrientDefinitions - add new nutrients there
        NutrientDefinitions.all.contains { product.nutrientValue(for: $0.id) != nil }
    }

    // MARK: - Editable Sections

    private var editableBasicInfoSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Product Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Name", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: "name")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Brand (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Brand", text: $editBrand)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: "brand")
            }

            if let barcode = product.barcode {
                HStack {
                    Text("Barcode:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(barcode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var editableNutritionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Nutrition Facts")
                    .font(.headline)
                Spacer()
                Text("Per 100\(product.servingSizeUnit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Main macros
            EditableNutritionRow(label: "Calories", value: $editCalories, unit: "kcal", focused: $focusedField, fieldId: "calories")
            EditableNutritionRow(label: "Protein", value: $editProtein, unit: "g", focused: $focusedField, fieldId: "protein")
            EditableNutritionRow(label: "Carbohydrates", value: $editCarbs, unit: "g", focused: $focusedField, fieldId: "carbs")
            EditableNutritionRow(label: "Fat", value: $editFat, unit: "g", focused: $focusedField, fieldId: "fat")
            EditableNutritionRow(label: "Saturated Fat", value: $editSaturatedFat, unit: "g", focused: $focusedField, fieldId: "satfat")
            EditableNutritionRow(label: "Fibre", value: $editFibre, unit: "g", focused: $focusedField, fieldId: "fibre")
            EditableNutritionRow(label: "Natural Sugar", value: $editNaturalSugar, unit: "g", focused: $focusedField, fieldId: "natsugar")
            EditableNutritionRow(label: "Added Sugar", value: $editAddedSugar, unit: "g", focused: $focusedField, fieldId: "addsugar")
            EditableNutritionRow(label: "Sodium", value: $editSodium, unit: "mg", focused: $focusedField, fieldId: "sodium")
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var editableVitaminsMineralsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vitamins & Minerals")
                .font(.headline)

            Text("Vitamins")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(NutrientDefinitions.vitamins) { def in
                EditableNutrientRow(
                    definition: def,
                    value: Binding(
                        get: { editNutrients[def.id] ?? "" },
                        set: { editNutrients[def.id] = $0 }
                    ),
                    focused: $focusedField
                )
            }

            Divider()

            Text("Minerals")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(NutrientDefinitions.minerals) { def in
                EditableNutrientRow(
                    definition: def,
                    value: Binding(
                        get: { editNutrients[def.id] ?? "" },
                        set: { editNutrients[def.id] = $0 }
                    ),
                    focused: $focusedField
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Edit Helpers

    private func loadEditValues() {
        editName = product.name
        editBrand = product.brand ?? ""
        editCalories = String(format: "%.1f", product.calories)
        editProtein = String(format: "%.1f", product.protein)
        editCarbs = String(format: "%.1f", product.carbohydrates)
        editFat = String(format: "%.1f", product.fat)
        editSaturatedFat = product.saturatedFat.map { String(format: "%.1f", $0) } ?? ""
        editFibre = product.fibre.map { String(format: "%.1f", $0) } ?? ""
        editNaturalSugar = product.naturalSugar.map { String(format: "%.1f", $0) } ?? ""
        editAddedSugar = product.addedSugar.map { String(format: "%.1f", $0) } ?? ""
        editSodium = product.sodium.map { String(format: "%.1f", $0) } ?? ""

        // Load vitamin/mineral values
        editNutrients = [:]
        for def in NutrientDefinitions.all {
            if let value = product.nutrientValue(for: def.id) {
                editNutrients[def.id] = String(format: "%.\(def.decimalPlaces)f", value)
            }
        }
    }

    private func saveChanges() {
        product.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        product.brand = editBrand.isEmpty ? nil : editBrand.trimmingCharacters(in: .whitespacesAndNewlines)
        product.calories = Double(editCalories) ?? product.calories
        product.protein = Double(editProtein) ?? product.protein
        product.carbohydrates = Double(editCarbs) ?? product.carbohydrates
        product.fat = Double(editFat) ?? product.fat
        product.saturatedFat = Double(editSaturatedFat)
        product.fibre = Double(editFibre)
        product.naturalSugar = Double(editNaturalSugar)
        product.addedSugar = Double(editAddedSugar)
        product.sodium = Double(editSodium)

        // Save vitamin/mineral values
        for def in NutrientDefinitions.all {
            let value = Double(editNutrients[def.id] ?? "")
            product.setNutrientValue(value, for: def.id)
        }
    }
}

// MARK: - Editable Nutrition Row
struct EditableNutritionRow: View {
    let label: String
    @Binding var value: String
    let unit: String
    var focused: FocusState<String?>.Binding
    let fieldId: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 4) {
                TextField("0", text: $value)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .focused(focused, equals: fieldId)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
            }
        }
    }
}

// MARK: - Editable Nutrient Row (for vitamins/minerals)
struct EditableNutrientRow: View {
    let definition: NutrientDefinition
    @Binding var value: String
    var focused: FocusState<String?>.Binding

    var body: some View {
        HStack {
            Text(definition.shortName)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 4) {
                TextField("0", text: $value)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .focused(focused, equals: definition.id)
                Text(definition.unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
            }
        }
    }
}

// MARK: - Product Photo Picker Sheet
struct ProductPhotoPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    @State private var showingCameraPicker = false
    @State private var showingLibraryPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 20) {
                    Text("Add Photo")
                        .font(.title2)
                        .fontWeight(.bold)

                    // Camera option
                    Button {
                        showingCameraPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .frame(width: 50)
                            VStack(alignment: .leading) {
                                Text("Take Photo")
                                    .font(.headline)
                                Text("Use camera to take a new photo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Photo library option
                    Button {
                        showingLibraryPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                .foregroundStyle(.purple)
                                .frame(width: 50)
                            VStack(alignment: .leading) {
                                Text("Choose from Library")
                                    .font(.headline)
                                Text("Select an existing photo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCameraPicker) {
                CameraPickerView { image in
                    onCapture(image)
                    dismiss()
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingLibraryPicker) {
                LibraryPickerView { image in
                    onCapture(image)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Camera Picker View
struct CameraPickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - Library Picker View
struct LibraryPickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - Nutrition Row
struct NutritionRow: View {
    let label: String
    let value: Double
    let unit: String
    var isHighlighted = false

    var body: some View {
        HStack {
            Text(label)
                .font(isHighlighted ? .headline : .subheadline)
            Spacer()
            Text("\(value, specifier: value >= 10 ? "%.0f" : "%.1f") \(unit)")
                .font(isHighlighted ? .headline : .subheadline)
                .fontWeight(isHighlighted ? .bold : .regular)
        }
    }
}

// MARK: - Add Product to Today Sheet
struct AddProductToTodaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let product: Product
    @Binding var amount: Double
    let onAdd: () -> Void

    @FocusState private var amountFocused: Bool

    // Calculate nutrition preview
    private var scale: Double { amount / 100.0 }
    private var previewCalories: Double { product.calories * scale }
    private var previewProtein: Double { product.protein * scale }
    private var previewCarbs: Double { product.carbohydrates * scale }
    private var previewFat: Double { product.fat * scale }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Product info header
                HStack(spacing: 12) {
                    if let image = product.displayImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "cart.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, height: 60)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.headline)
                            .lineLimit(2)
                        if let brand = product.brand {
                            Text(brand)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Amount input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.headline)

                    HStack {
                        TextField("Amount", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .focused($amountFocused)

                        Text(product.servingSizeUnit)
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Quick amount buttons
                        HStack(spacing: 8) {
                            ForEach([50.0, 100.0, 150.0, 200.0], id: \.self) { quickAmount in
                                Button("\(Int(quickAmount))") {
                                    amount = quickAmount
                                }
                                .buttonStyle(.bordered)
                                .tint(amount == quickAmount ? .green : .gray)
                            }
                        }
                    }
                }

                // Nutrition preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nutrition Preview")
                        .font(.headline)

                    HStack(spacing: 16) {
                        NutritionPreviewItem(label: "Calories", value: previewCalories, unit: "kcal", color: .orange)
                        NutritionPreviewItem(label: "Protein", value: previewProtein, unit: "g", color: .blue)
                        NutritionPreviewItem(label: "Carbs", value: previewCarbs, unit: "g", color: .green)
                        NutritionPreviewItem(label: "Fat", value: previewFat, unit: "g", color: .purple)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()

                // Add button
                Button {
                    onAdd()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add \(Int(amount))\(product.servingSizeUnit) to Today")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(amount <= 0)
            }
            .padding()
            .navigationTitle("Add to Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Nutrition Preview Item
struct NutritionPreviewItem: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(value))")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProductListView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self], inMemory: true)
}
