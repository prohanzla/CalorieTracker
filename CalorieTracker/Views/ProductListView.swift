// ProductListView.swift - List of all saved products
// Made by mpcode

import SwiftUI
import SwiftData

struct ProductListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Product.name) private var products: [Product]

    @State private var searchText = ""
    @State private var selectedProduct: Product?
    @State private var showingDeleteConfirmation = false
    @State private var productToDelete: Product?

    var filteredProducts: [Product] {
        if searchText.isEmpty {
            return products
        }
        return products.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.brand?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.barcode?.contains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if products.isEmpty {
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
                }
            }
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
            // Product image or placeholder
            Group {
                if let imageData = product.imageData,
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

                    if product.isCustom {
                        Label("Custom", systemImage: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
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
    let product: Product

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Product image
                    if let imageData = product.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

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
                            NutritionRow(label: "  Saturated Fat", value: saturatedFat, unit: "g")
                        }
                        if let fibre = product.fibre {
                            NutritionRow(label: "Fibre", value: fibre, unit: "g")
                        }
                        if let sugar = product.sugar {
                            NutritionRow(label: "Sugar", value: sugar, unit: "g")
                        }
                        if let sodium = product.sodium {
                            NutritionRow(label: "Sodium", value: sodium, unit: "mg")
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Vitamins & Minerals (if available)
                    if hasVitaminsOrMinerals {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Vitamins & Minerals")
                                .font(.headline)

                            if let vitA = product.vitaminA {
                                NutritionRow(label: "Vitamin A", value: vitA, unit: "%")
                            }
                            if let vitC = product.vitaminC {
                                NutritionRow(label: "Vitamin C", value: vitC, unit: "%")
                            }
                            if let vitD = product.vitaminD {
                                NutritionRow(label: "Vitamin D", value: vitD, unit: "%")
                            }
                            if let calcium = product.calcium {
                                NutritionRow(label: "Calcium", value: calcium, unit: "mg")
                            }
                            if let iron = product.iron {
                                NutritionRow(label: "Iron", value: iron, unit: "mg")
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
        }
    }

    private var hasVitaminsOrMinerals: Bool {
        product.vitaminA != nil || product.vitaminC != nil ||
        product.vitaminD != nil || product.calcium != nil || product.iron != nil
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
