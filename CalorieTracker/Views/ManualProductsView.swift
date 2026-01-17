// ManualProductsView.swift - List of manually added products (no barcode)
// Made by mpcode

import SwiftUI
import SwiftData

struct ManualProductsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Product.dateAdded, order: .reverse) private var allProducts: [Product]

    @State private var searchText = ""
    @State private var selectedProduct: Product?
    @State private var showingDeleteConfirmation = false
    @State private var productToDelete: Product?

    // Only show products WITHOUT barcodes (manual/AI-generated)
    private var manualProducts: [Product] {
        allProducts.filter { $0.barcode == nil || $0.barcode!.isEmpty }
    }

    var filteredProducts: [Product] {
        if searchText.isEmpty {
            return manualProducts
        }
        return manualProducts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
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
                        Text("V4")
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
                    if manualProducts.isEmpty {
                        ContentUnavailableView {
                            Label("No Manual Products", systemImage: "square.and.pencil")
                        } description: {
                            Text("Add products manually or use AI Quick Add to build your custom foods database.")
                        }
                    } else {
                        List {
                            ForEach(filteredProducts) { product in
                                ManualProductListRow(product: product)
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
                        .searchable(text: $searchText, prompt: "Search manual products")
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Manual Products")
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

// MARK: - Manual Product List Row
struct ManualProductListRow: View {
    let product: Product

    // Display text for serving info
    private var servingText: String {
        if let portionSize = product.portionSize, portionSize > 0 {
            return "per \(Int(portionSize))g portion"
        } else {
            return "per \(Int(product.servingSize))\(product.servingSizeUnit)"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Product image - prefer main photo, then nutrition label, then emoji
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
                    // Show emoji based on name matching
                    Text(product.displayEmoji)
                        .font(.title)
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

                if let brand = product.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Show notes if available
                if let notes = product.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(product.calories))")
                    .font(.headline)
                Text("kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(servingText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ManualProductsView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self], inMemory: true)
}
