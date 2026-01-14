// ManualEntryView.swift - Manual product/food entry form
// Made by mpcode

import SwiftUI
import SwiftData

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var brand = ""
    @State private var barcode = ""
    @State private var servingSize = "100"
    @State private var servingSizeUnit = "g"
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbohydrates = ""
    @State private var fat = ""
    @State private var saturatedFat = ""
    @State private var fibre = ""
    @State private var sugar = ""
    @State private var sodium = ""

    @State private var addToTodayLog = true
    @State private var showingAdvanced = false

    let servingUnits = ["g", "ml", "oz", "cup", "piece"]

    var isValid: Bool {
        !name.isEmpty && !calories.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Product Information") {
                    TextField("Product Name *", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    TextField("Barcode (optional)", text: $barcode)
                        .keyboardType(.numberPad)
                }

                // Serving size
                Section("Serving Size") {
                    HStack {
                        TextField("Amount", text: $servingSize)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 100)

                        Picker("Unit", selection: $servingSizeUnit) {
                            ForEach(servingUnits, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Main nutrition
                Section("Nutrition (per serving)") {
                    NutritionTextField(label: "Calories *", value: $calories, unit: "kcal")
                    NutritionTextField(label: "Protein", value: $protein, unit: "g")
                    NutritionTextField(label: "Carbohydrates", value: $carbohydrates, unit: "g")
                    NutritionTextField(label: "Fat", value: $fat, unit: "g")
                }

                // Advanced nutrition (expandable)
                Section {
                    DisclosureGroup("Additional Nutrition", isExpanded: $showingAdvanced) {
                        NutritionTextField(label: "Saturated Fat", value: $saturatedFat, unit: "g")
                        NutritionTextField(label: "Fibre", value: $fibre, unit: "g")
                        NutritionTextField(label: "Sugar", value: $sugar, unit: "g")
                        NutritionTextField(label: "Sodium", value: $sodium, unit: "mg")
                    }
                }

                // Add to log option
                Section {
                    Toggle("Add to today's log", isOn: $addToTodayLog)
                }

                // Required fields note
                Section {
                    Text("* Required fields")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        saveProduct()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func saveProduct() {
        let product = Product(
            name: name,
            barcode: barcode.isEmpty ? nil : barcode,
            brand: brand.isEmpty ? nil : brand,
            servingSize: Double(servingSize) ?? 100,
            servingSizeUnit: servingSizeUnit,
            calories: Double(calories) ?? 0,
            protein: Double(protein) ?? 0,
            carbohydrates: Double(carbohydrates) ?? 0,
            fat: Double(fat) ?? 0,
            isCustom: true
        )

        // Set optional values
        product.saturatedFat = Double(saturatedFat)
        product.fibre = Double(fibre)
        product.sugar = Double(sugar)
        product.sodium = Double(sodium)

        modelContext.insert(product)

        if addToTodayLog {
            addToLog(product)
        }

        dismiss()
    }

    private func addToLog(_ product: Product) {
        // Find or create today's log
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == today }
        )

        let log: DailyLog
        if let existingLog = try? modelContext.fetch(descriptor).first {
            log = existingLog
        } else {
            log = DailyLog()
            modelContext.insert(log)
        }

        let entry = FoodEntry(
            product: product,
            amount: product.servingSize,
            unit: product.servingSizeUnit,
            calories: product.calories,
            protein: product.protein,
            carbohydrates: product.carbohydrates,
            fat: product.fat
        )
        entry.dailyLog = log
        modelContext.insert(entry)
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
