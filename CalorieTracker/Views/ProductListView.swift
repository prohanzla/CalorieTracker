// ProductListView.swift - List of all saved products
// Made by mpcode

import SwiftUI
import SwiftData

struct ProductListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Product.name) private var allProducts: [Product]

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

                    // Basic info
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

                    Divider()

                    // Nutrition per serving
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

                    // Vitamins & Minerals (if available) - uses centralized NutrientDefinitions
                    if hasVitaminsOrMinerals {
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
            .navigationTitle("Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
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
        }
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

#Preview {
    ProductListView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self], inMemory: true)
}
