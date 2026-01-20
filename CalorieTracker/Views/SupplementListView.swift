// SupplementListView.swift - List and manage supplements
// Made by mpcode

import SwiftUI
import SwiftData
import UIKit

struct SupplementListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Supplement.name) private var allSupplements: [Supplement]

    @State private var searchText = ""
    @State private var selectedSupplement: Supplement?
    @State private var showingAddSupplement = false
    @State private var showingDeleteConfirmation = false
    @State private var supplementToDelete: Supplement?

    var filteredSupplements: [Supplement] {
        if searchText.isEmpty {
            return allSupplements
        }
        return allSupplements.filter {
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
                        Text("V16")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.purple))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 50)
                .padding(.leading, 8)

                Group {
                    if allSupplements.isEmpty {
                        ContentUnavailableView {
                            Label("No Supplements", systemImage: "pill.fill")
                        } description: {
                            Text("Add your daily vitamins and supplements to track your nutrient intake.")
                        } actions: {
                            Button {
                                showingAddSupplement = true
                            } label: {
                                Label("Add Supplement", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        List {
                            ForEach(filteredSupplements) { supplement in
                                SupplementRow(supplement: supplement)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedSupplement = supplement
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            supplementToDelete = supplement
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .searchable(text: $searchText, prompt: "Search supplements")
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Supplements")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSupplement = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $selectedSupplement) { supplement in
                SupplementDetailView(supplement: supplement)
            }
            .sheet(isPresented: $showingAddSupplement) {
                AddSupplementView()
            }
            .confirmationDialog(
                "Delete Supplement",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let supplement = supplementToDelete {
                        deleteSupplement(supplement)
                    }
                }
                Button("Cancel", role: .cancel) {
                    supplementToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this supplement? This cannot be undone.")
            }
        }
    }

    private func deleteSupplement(_ supplement: Supplement) {
        modelContext.delete(supplement)
        supplementToDelete = nil
    }
}

// MARK: - Supplement Row
struct SupplementRow: View {
    let supplement: Supplement

    var body: some View {
        HStack(spacing: 12) {
            // Supplement icon
            Group {
                if let image = supplement.displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: supplement.dosageFormIcon)
                        .font(.title2)
                        .foregroundStyle(.purple)
                }
            }
            .frame(width: 50, height: 50)
            .background(Color.purple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(supplement.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let brand = supplement.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(Int(supplement.servingSize)) \(supplement.servingSizeUnit)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Nutrient count badge
            if supplement.hasNutrientData {
                let nutrientCount = countNutrients(supplement)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(nutrientCount)")
                        .font(.headline)
                        .foregroundStyle(.purple)
                    Text("nutrients")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func countNutrients(_ supplement: Supplement) -> Int {
        NutrientDefinitions.all.filter { supplement.nutrientValue(for: $0.id) != nil }.count
    }
}

// MARK: - Supplement Detail View
struct SupplementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var supplement: Supplement

    @State private var isEditing = false
    @State private var showingAddToToday = false
    @State private var addAmount: Double = 1
    @State private var showingAddSuccess = false

    // Edit mode state
    @State private var editName: String = ""
    @State private var editBrand: String = ""
    @State private var editDosageForm: String = "tablet"
    @State private var editServingSize: String = ""
    @State private var editNutrients: [String: String] = [:]

    @FocusState private var focusedField: String?

    private var dateManager: SelectedDateManager { SelectedDateManager.shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // DEBUG badge
                    HStack {
                        Text("V17")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.purple))
                        Text("SupplementDetailView")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    // Image/Icon section
                    Group {
                        if let image = supplement.displayImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            Image(systemName: supplement.dosageFormIcon)
                                .font(.system(size: 40))
                                .foregroundStyle(.purple)
                                .frame(width: 100, height: 100)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    // Basic info
                    if isEditing {
                        editableBasicInfoSection
                    } else {
                        VStack(spacing: 8) {
                            Text(supplement.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            if let brand = supplement.brand {
                                Text(brand)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 8) {
                                Image(systemName: supplement.dosageFormIcon)
                                Text("\(Int(supplement.servingSize)) \(supplement.servingSizeUnit) per serving")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    // Nutrients section
                    if isEditing {
                        editableNutrientsSection
                    } else if supplement.hasNutrientData {
                        nutrientsDisplaySection
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "leaf")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No nutrient data")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Tap Edit to add vitamin and mineral values")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Supplement" : "Supplement Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("Cancel") {
                            isEditing = false
                        }
                    } else {
                        Button {
                            addAmount = supplement.servingSize
                            showingAddToToday = true
                        } label: {
                            Label("Log Intake", systemImage: "plus.circle.fill")
                                .foregroundStyle(.purple)
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
            .sheet(isPresented: $showingAddToToday) {
                LogSupplementSheet(
                    supplement: supplement,
                    amount: $addAmount,
                    onAdd: { logSupplement() }
                )
                .presentationDetents([.medium])
            }
            .alert("Logged Successfully", isPresented: $showingAddSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("\(Int(addAmount)) \(supplement.servingSizeUnit) of \(supplement.name) logged.")
            }
        }
    }

    // MARK: - Display Section
    private var nutrientsDisplaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrients (per serving)")
                .font(.headline)

            // Vitamins
            let vitaminsWithValues = NutrientDefinitions.vitamins.filter { supplement.nutrientValue(for: $0.id) != nil }
            if !vitaminsWithValues.isEmpty {
                Text("Vitamins")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(vitaminsWithValues) { def in
                    if let value = supplement.nutrientValue(for: def.id) {
                        NutrientDisplayRow(definition: def, value: value)
                    }
                }
            }

            // Minerals
            let mineralsWithValues = NutrientDefinitions.minerals.filter { supplement.nutrientValue(for: $0.id) != nil }
            if !mineralsWithValues.isEmpty {
                if !vitaminsWithValues.isEmpty {
                    Divider()
                }

                Text("Minerals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(mineralsWithValues) { def in
                    if let value = supplement.nutrientValue(for: def.id) {
                        NutrientDisplayRow(definition: def, value: value)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Editable Sections
    private var editableBasicInfoSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Supplement Name")
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

            VStack(alignment: .leading, spacing: 4) {
                Text("Dosage Form")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Form", selection: $editDosageForm) {
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
                    TextField("1", text: $editServingSize)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .focused($focusedField, equals: "serving")
                    Text(editDosageForm)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var editableNutrientsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrients (per serving)")
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
        editName = supplement.name
        editBrand = supplement.brand ?? ""
        editDosageForm = supplement.dosageForm
        editServingSize = String(format: "%.0f", supplement.servingSize)

        editNutrients = [:]
        for def in NutrientDefinitions.all {
            if let value = supplement.nutrientValue(for: def.id) {
                editNutrients[def.id] = String(format: "%.\(def.decimalPlaces)f", value)
            }
        }
    }

    private func saveChanges() {
        supplement.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        supplement.brand = editBrand.isEmpty ? nil : editBrand.trimmingCharacters(in: .whitespacesAndNewlines)
        supplement.dosageForm = editDosageForm
        supplement.servingSize = Double(editServingSize) ?? supplement.servingSize
        supplement.servingSizeUnit = editDosageForm

        for def in NutrientDefinitions.all {
            let value = Double(editNutrients[def.id] ?? "")
            supplement.setNutrientValue(value, for: def.id)
        }
    }

    // MARK: - Log Supplement
    private func logSupplement() {
        let entry = SupplementEntry(
            supplement: supplement,
            amount: addAmount,
            unit: supplement.servingSizeUnit
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
}

// MARK: - Nutrient Display Row
struct NutrientDisplayRow: View {
    let definition: NutrientDefinition
    let value: Double

    var body: some View {
        HStack {
            Text(definition.name)
                .font(.subheadline)
            Spacer()
            Text(String(format: "%.\(definition.decimalPlaces)f \(definition.unit)", value))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Show percentage of RDA
            let percentage = (value / definition.target) * 100
            Text(String(format: "%.0f%%", percentage))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(percentage >= 100 ? .green : .orange)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

// MARK: - Log Supplement Sheet
struct LogSupplementSheet: View {
    @Environment(\.dismiss) private var dismiss
    let supplement: Supplement
    @Binding var amount: Double
    let onAdd: () -> Void

    @FocusState private var amountFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Supplement info header
                HStack(spacing: 12) {
                    Image(systemName: supplement.dosageFormIcon)
                        .font(.title)
                        .foregroundStyle(.purple)
                        .frame(width: 60, height: 60)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(supplement.name)
                            .font(.headline)
                            .lineLimit(2)
                        if let brand = supplement.brand {
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

                        Text(supplement.servingSizeUnit)
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Quick amount buttons
                        HStack(spacing: 8) {
                            ForEach([1.0, 2.0, 3.0], id: \.self) { quickAmount in
                                Button("\(Int(quickAmount))") {
                                    amount = quickAmount
                                }
                                .buttonStyle(.bordered)
                                .tint(amount == quickAmount ? .purple : .gray)
                            }
                        }
                    }
                }

                // Nutrients preview
                if supplement.hasNutrientData {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You'll get")
                            .font(.headline)

                        let scale = amount / supplement.servingSize
                        let topNutrients = NutrientDefinitions.all
                            .compactMap { def -> (NutrientDefinition, Double)? in
                                guard let value = supplement.nutrientValue(for: def.id) else { return nil }
                                return (def, value * scale)
                            }
                            .prefix(4)

                        HStack(spacing: 8) {
                            ForEach(Array(topNutrients), id: \.0.id) { def, value in
                                VStack(spacing: 4) {
                                    Text(def.shortName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.0f", (value / def.target) * 100) + "%")
                                        .font(.headline)
                                        .foregroundStyle(.purple)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Spacer()

                // Log button
                Button {
                    onAdd()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Log \(Int(amount)) \(supplement.servingSizeUnit)")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(amount <= 0)
            }
            .padding()
            .navigationTitle("Log Supplement")
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

#Preview {
    SupplementListView()
        .modelContainer(for: [Supplement.self, SupplementEntry.self, DailyLog.self], inMemory: true)
}
