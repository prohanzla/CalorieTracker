// AddSupplementView.swift - Add new supplements to the database
// Made by mpcode

import SwiftUI
import SwiftData

struct AddSupplementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Basic info
    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var dosageForm: String = "tablet"
    @State private var servingSize: String = "1"

    // Nutrients - dictionary with nutrient ID as key
    @State private var nutrientValues: [String: String] = [:]

    // UI state
    @State private var showingVitamins = true
    @State private var showingMinerals = true

    @FocusState private var focusedField: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // DEBUG badge
                        HStack {
                            Text("V18")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.purple))
                            Text("AddSupplementView")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        // Basic info section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Supplement Info")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name *")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("e.g., Multivitamin, Vitamin D3, Fish Oil", text: $name)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: "name")
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Brand (optional)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("e.g., Nature Made, Centrum", text: $brand)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: "brand")
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dosage Form")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("Form", selection: $dosageForm) {
                                    ForEach(Supplement.dosageForms, id: \.self) { form in
                                        Text(form.capitalized).tag(form)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Serving Size")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    TextField("1", text: $servingSize)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .focused($focusedField, equals: "serving")
                                    Text(dosageForm + "(s) per serving")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Vitamins section
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                withAnimation {
                                    showingVitamins.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("Vitamins")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: showingVitamins ? "chevron.up" : "chevron.down")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            if showingVitamins {
                                Text("Enter values per serving (leave blank if not applicable)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ForEach(NutrientDefinitions.vitamins) { def in
                                    NutrientInputRow(
                                        definition: def,
                                        value: Binding(
                                            get: { nutrientValues[def.id] ?? "" },
                                            set: { nutrientValues[def.id] = $0 }
                                        ),
                                        focused: $focusedField
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Minerals section
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                withAnimation {
                                    showingMinerals.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("Minerals")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: showingMinerals ? "chevron.up" : "chevron.down")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            if showingMinerals {
                                Text("Enter values per serving (leave blank if not applicable)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ForEach(NutrientDefinitions.minerals) { def in
                                    NutrientInputRow(
                                        definition: def,
                                        value: Binding(
                                            get: { nutrientValues[def.id] ?? "" },
                                            set: { nutrientValues[def.id] = $0 }
                                        ),
                                        focused: $focusedField
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Quick presets section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Presets")
                                .font(.headline)

                            Text("Tap to auto-fill common supplements")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                PresetButton(title: "Vitamin D3", icon: "sun.max.fill") {
                                    applyPreset(vitaminD3Preset)
                                }
                                PresetButton(title: "Vitamin C", icon: "leaf.fill") {
                                    applyPreset(vitaminCPreset)
                                }
                                PresetButton(title: "B-Complex", icon: "bolt.fill") {
                                    applyPreset(bComplexPreset)
                                }
                                PresetButton(title: "Multivitamin", icon: "pills.fill") {
                                    applyPreset(multivitaminPreset)
                                }
                                PresetButton(title: "Omega-3", icon: "drop.fill") {
                                    applyPreset(omega3Preset)
                                }
                                PresetButton(title: "Magnesium", icon: "moon.fill") {
                                    applyPreset(magnesiumPreset)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Spacer for keyboard
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSupplement()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Save
    private func saveSupplement() {
        let supplement = Supplement(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespacesAndNewlines),
            dosageForm: dosageForm,
            servingSize: Double(servingSize) ?? 1,
            servingSizeUnit: dosageForm
        )

        // Set nutrient values
        for def in NutrientDefinitions.all {
            if let valueStr = nutrientValues[def.id], let value = Double(valueStr), value > 0 {
                supplement.setNutrientValue(value, for: def.id)
            }
        }

        modelContext.insert(supplement)
        dismiss()
    }

    // MARK: - Presets
    private struct SupplementPreset {
        let name: String
        let brand: String?
        let dosageForm: String
        let servingSize: Double
        let nutrients: [String: Double]
    }

    private let vitaminD3Preset = SupplementPreset(
        name: "Vitamin D3",
        brand: nil,
        dosageForm: "softgel",
        servingSize: 1,
        nutrients: ["vitaminD": 25] // 1000 IU = 25mcg
    )

    private let vitaminCPreset = SupplementPreset(
        name: "Vitamin C",
        brand: nil,
        dosageForm: "tablet",
        servingSize: 1,
        nutrients: ["vitaminC": 500]
    )

    private let bComplexPreset = SupplementPreset(
        name: "B-Complex",
        brand: nil,
        dosageForm: "capsule",
        servingSize: 1,
        nutrients: [
            "vitaminB1": 1.5,
            "vitaminB2": 1.7,
            "vitaminB3": 20,
            "vitaminB5": 10,
            "vitaminB6": 2,
            "vitaminB7": 30,
            "vitaminB12": 6,
            "folate": 400
        ]
    )

    private let multivitaminPreset = SupplementPreset(
        name: "Daily Multivitamin",
        brand: nil,
        dosageForm: "tablet",
        servingSize: 1,
        nutrients: [
            "vitaminA": 900,
            "vitaminC": 90,
            "vitaminD": 20,
            "vitaminE": 15,
            "vitaminK": 120,
            "vitaminB1": 1.2,
            "vitaminB2": 1.3,
            "vitaminB3": 16,
            "vitaminB5": 5,
            "vitaminB6": 1.7,
            "vitaminB7": 30,
            "vitaminB12": 2.4,
            "folate": 400,
            "calcium": 200,
            "iron": 18,
            "zinc": 11,
            "magnesium": 50,
            "selenium": 55,
            "copper": 0.9,
            "manganese": 2.3,
            "chromium": 35,
            "molybdenum": 45,
            "iodine": 150
        ]
    )

    private let omega3Preset = SupplementPreset(
        name: "Omega-3 Fish Oil",
        brand: nil,
        dosageForm: "softgel",
        servingSize: 1,
        nutrients: [:] // No vitamins/minerals in fish oil
    )

    private let magnesiumPreset = SupplementPreset(
        name: "Magnesium",
        brand: nil,
        dosageForm: "capsule",
        servingSize: 1,
        nutrients: ["magnesium": 200]
    )

    private func applyPreset(_ preset: SupplementPreset) {
        name = preset.name
        brand = preset.brand ?? ""
        dosageForm = preset.dosageForm
        servingSize = String(format: "%.0f", preset.servingSize)

        // Clear existing values
        nutrientValues = [:]

        // Apply preset values
        for (id, value) in preset.nutrients {
            if let def = NutrientDefinitions.nutrient(for: id) {
                nutrientValues[id] = String(format: "%.\(def.decimalPlaces)f", value)
            }
        }
    }
}

// MARK: - Nutrient Input Row
struct NutrientInputRow: View {
    let definition: NutrientDefinition
    @Binding var value: String
    var focused: FocusState<String?>.Binding

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name)
                    .font(.subheadline)
                Text("RDA: \(String(format: "%.0f", definition.target)) \(definition.unit)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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

// MARK: - Preset Button
struct PresetButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.purple)
                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.purple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddSupplementView()
        .modelContainer(for: [Supplement.self, SupplementEntry.self, DailyLog.self], inMemory: true)
}
