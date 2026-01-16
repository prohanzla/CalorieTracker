// DataBackupManager.swift - Export and import food data for manual backup
// Made by mpcode

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Manages export and import of user food data
@Observable
class DataBackupManager {
    static let shared = DataBackupManager()

    private init() {}

    // MARK: - Export Data

    /// Export all user data to a JSON file
    func exportData(from context: ModelContext) throws -> Data {
        // Fetch all data
        let products = try context.fetch(FetchDescriptor<Product>())
        let dailyLogs = try context.fetch(FetchDescriptor<DailyLog>())
        let foodEntries = try context.fetch(FetchDescriptor<FoodEntry>())
        let aiTemplates = try context.fetch(FetchDescriptor<AIFoodTemplate>())

        // Create export structure
        let exportData = BackupData(
            version: 1,
            exportDate: Date(),
            products: products.map { ProductBackup(from: $0) },
            dailyLogs: dailyLogs.map { DailyLogBackup(from: $0) },
            foodEntries: foodEntries.map { FoodEntryBackup(from: $0) },
            aiTemplates: aiTemplates.map { AITemplateBackup(from: $0) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(exportData)
    }

    /// Generate filename for export
    func generateExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = formatter.string(from: Date())
        return "CalorieTracker_Backup_\(dateString).json"
    }

    // MARK: - Import Data

    /// Import data from a JSON backup file
    func importData(_ data: Data, into context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backupData = try decoder.decode(BackupData.self, from: data)

        var result = ImportResult()

        // Import products first (other entities reference them)
        var productIdMap: [UUID: Product] = [:]

        for productBackup in backupData.products {
            // Check if product already exists (by barcode or name+brand)
            let existingProduct = findExistingProduct(productBackup, in: context)

            if let existing = existingProduct {
                productIdMap[productBackup.id] = existing
                result.productsSkipped += 1
            } else {
                let product = productBackup.toProduct()
                context.insert(product)
                productIdMap[productBackup.id] = product
                result.productsImported += 1
            }
        }

        // Import daily logs
        var logIdMap: [UUID: DailyLog] = [:]

        for logBackup in backupData.dailyLogs {
            // Check if log for this date already exists
            let existingLog = findExistingLog(for: logBackup.date, in: context)

            if let existing = existingLog {
                logIdMap[logBackup.id] = existing
                result.logsSkipped += 1
            } else {
                let log = logBackup.toDailyLog()
                context.insert(log)
                logIdMap[logBackup.id] = log
                result.logsImported += 1
            }
        }

        // Import food entries
        for entryBackup in backupData.foodEntries {
            // Skip if entry already exists (same timestamp and calories)
            if entryAlreadyExists(entryBackup, in: context) {
                result.entriesSkipped += 1
                continue
            }

            let entry = entryBackup.toFoodEntry()

            // Link to product if exists
            if let productId = entryBackup.productId,
               let product = productIdMap[productId] {
                entry.product = product
            }

            // Link to daily log if exists
            if let logId = entryBackup.dailyLogId,
               let log = logIdMap[logId] {
                entry.dailyLog = log
            }

            context.insert(entry)
            result.entriesImported += 1
        }

        // Import AI templates
        for templateBackup in backupData.aiTemplates {
            // Check if template already exists (by name)
            if templateAlreadyExists(templateBackup.name, in: context) {
                result.templatesSkipped += 1
                continue
            }

            let template = templateBackup.toAIFoodTemplate()
            context.insert(template)
            result.templatesImported += 1
        }

        try context.save()

        return result
    }

    // MARK: - Helper Methods

    private func findExistingProduct(_ backup: ProductBackup, in context: ModelContext) -> Product? {
        // First try to find by barcode
        if let barcode = backup.barcode, !barcode.isEmpty {
            let barcodeToFind = barcode
            let descriptor = FetchDescriptor<Product>(
                predicate: #Predicate { $0.barcode == barcodeToFind }
            )
            if let existing = try? context.fetch(descriptor).first {
                return existing
            }
        }

        // Then try by exact name and brand match
        let nameToFind = backup.name
        let brandToFind = backup.brand
        let descriptor = FetchDescriptor<Product>(
            predicate: #Predicate { $0.name == nameToFind && $0.brand == brandToFind }
        )
        return try? context.fetch(descriptor).first
    }

    private func findExistingLog(for date: Date, in context: ModelContext) -> DailyLog? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        return try? context.fetch(descriptor).first
    }

    private func entryAlreadyExists(_ backup: FoodEntryBackup, in context: ModelContext) -> Bool {
        let timestamp = backup.timestamp
        let calories = backup.calories

        // Allow 1 second tolerance for timestamp comparison
        let startTime = timestamp.addingTimeInterval(-1)
        let endTime = timestamp.addingTimeInterval(1)

        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate {
                $0.timestamp >= startTime &&
                $0.timestamp <= endTime &&
                $0.calories == calories
            }
        )
        return (try? context.fetch(descriptor).first) != nil
    }

    private func templateAlreadyExists(_ name: String, in context: ModelContext) -> Bool {
        let nameToFind = name.lowercased()
        let descriptor = FetchDescriptor<AIFoodTemplate>()
        let templates = (try? context.fetch(descriptor)) ?? []
        return templates.contains { $0.name.lowercased() == nameToFind }
    }
}

// MARK: - Import Result

struct ImportResult {
    var productsImported = 0
    var productsSkipped = 0
    var logsImported = 0
    var logsSkipped = 0
    var entriesImported = 0
    var entriesSkipped = 0
    var templatesImported = 0
    var templatesSkipped = 0

    var summary: String {
        var parts: [String] = []

        if productsImported > 0 {
            parts.append("\(productsImported) products")
        }
        if logsImported > 0 {
            parts.append("\(logsImported) days")
        }
        if entriesImported > 0 {
            parts.append("\(entriesImported) entries")
        }
        if templatesImported > 0 {
            parts.append("\(templatesImported) templates")
        }

        if parts.isEmpty {
            return "No new data imported (all items already exist)"
        }

        return "Imported: " + parts.joined(separator: ", ")
    }

    var skippedSummary: String {
        let total = productsSkipped + logsSkipped + entriesSkipped + templatesSkipped
        if total == 0 {
            return ""
        }
        return "\(total) duplicate items skipped"
    }
}

// MARK: - Backup Data Structures

struct BackupData: Codable {
    let version: Int
    let exportDate: Date
    let products: [ProductBackup]
    let dailyLogs: [DailyLogBackup]
    let foodEntries: [FoodEntryBackup]
    let aiTemplates: [AITemplateBackup]
}

struct ProductBackup: Codable {
    let id: UUID
    let name: String
    let barcode: String?
    let brand: String?
    let emoji: String?
    let servingSize: Double
    let servingSizeUnit: String
    let portionSize: Double?
    let portionsPerPackage: Int?
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let saturatedFat: Double?
    let transFat: Double?
    let fibre: Double?
    let sugar: Double?
    let naturalSugar: Double?
    let addedSugar: Double?
    let sodium: Double?
    let cholesterol: Double?
    let vitaminA: Double?
    let vitaminC: Double?
    let vitaminD: Double?
    let vitaminE: Double?
    let vitaminK: Double?
    let vitaminB1: Double?
    let vitaminB2: Double?
    let vitaminB3: Double?
    let vitaminB5: Double?
    let vitaminB6: Double?
    let vitaminB7: Double?
    let vitaminB12: Double?
    let folate: Double?
    let calcium: Double?
    let iron: Double?
    let potassium: Double?
    let magnesium: Double?
    let zinc: Double?
    let phosphorus: Double?
    let selenium: Double?
    let copper: Double?
    let manganese: Double?
    let chromium: Double?
    let molybdenum: Double?
    let iodine: Double?
    let chloride: Double?
    let dateAdded: Date
    let isCustom: Bool

    // Images stored as Base64 strings
    let imageDataBase64: String?
    let mainImageDataBase64: String?

    // User notes
    let notes: String?

    init(from product: Product) {
        self.id = product.id
        self.name = product.name
        self.barcode = product.barcode
        self.brand = product.brand
        self.emoji = product.emoji
        self.servingSize = product.servingSize
        self.servingSizeUnit = product.servingSizeUnit
        self.portionSize = product.portionSize
        self.portionsPerPackage = product.portionsPerPackage
        self.calories = product.calories
        self.protein = product.protein
        self.carbohydrates = product.carbohydrates
        self.fat = product.fat
        self.saturatedFat = product.saturatedFat
        self.transFat = product.transFat
        self.fibre = product.fibre
        self.sugar = product.sugar
        self.naturalSugar = product.naturalSugar
        self.addedSugar = product.addedSugar
        self.sodium = product.sodium
        self.cholesterol = product.cholesterol
        self.vitaminA = product.vitaminA
        self.vitaminC = product.vitaminC
        self.vitaminD = product.vitaminD
        self.vitaminE = product.vitaminE
        self.vitaminK = product.vitaminK
        self.vitaminB1 = product.vitaminB1
        self.vitaminB2 = product.vitaminB2
        self.vitaminB3 = product.vitaminB3
        self.vitaminB5 = product.vitaminB5
        self.vitaminB6 = product.vitaminB6
        self.vitaminB7 = product.vitaminB7
        self.vitaminB12 = product.vitaminB12
        self.folate = product.folate
        self.calcium = product.calcium
        self.iron = product.iron
        self.potassium = product.potassium
        self.magnesium = product.magnesium
        self.zinc = product.zinc
        self.phosphorus = product.phosphorus
        self.selenium = product.selenium
        self.copper = product.copper
        self.manganese = product.manganese
        self.chromium = product.chromium
        self.molybdenum = product.molybdenum
        self.iodine = product.iodine
        self.chloride = product.chloride
        self.dateAdded = product.dateAdded
        self.isCustom = product.isCustom

        // Encode images as Base64
        self.imageDataBase64 = product.imageData?.base64EncodedString()
        self.mainImageDataBase64 = product.mainImageData?.base64EncodedString()

        // Notes
        self.notes = product.notes
    }

    func toProduct() -> Product {
        let product = Product(
            name: name,
            barcode: barcode,
            brand: brand,
            servingSize: servingSize,
            servingSizeUnit: servingSizeUnit,
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            isCustom: isCustom
        )
        product.emoji = emoji
        product.portionSize = portionSize
        product.portionsPerPackage = portionsPerPackage
        product.saturatedFat = saturatedFat
        product.transFat = transFat
        product.fibre = fibre
        product.sugar = sugar
        product.naturalSugar = naturalSugar
        product.addedSugar = addedSugar
        product.sodium = sodium
        product.cholesterol = cholesterol
        product.vitaminA = vitaminA
        product.vitaminC = vitaminC
        product.vitaminD = vitaminD
        product.vitaminE = vitaminE
        product.vitaminK = vitaminK
        product.vitaminB1 = vitaminB1
        product.vitaminB2 = vitaminB2
        product.vitaminB3 = vitaminB3
        product.vitaminB5 = vitaminB5
        product.vitaminB6 = vitaminB6
        product.vitaminB7 = vitaminB7
        product.vitaminB12 = vitaminB12
        product.folate = folate
        product.calcium = calcium
        product.iron = iron
        product.potassium = potassium
        product.magnesium = magnesium
        product.zinc = zinc
        product.phosphorus = phosphorus
        product.selenium = selenium
        product.copper = copper
        product.manganese = manganese
        product.chromium = chromium
        product.molybdenum = molybdenum
        product.iodine = iodine
        product.chloride = chloride

        // Decode images from Base64
        if let imageBase64 = imageDataBase64 {
            product.imageData = Data(base64Encoded: imageBase64)
        }
        if let mainImageBase64 = mainImageDataBase64 {
            product.mainImageData = Data(base64Encoded: mainImageBase64)
        }

        // Notes
        product.notes = notes

        return product
    }
}

struct DailyLogBackup: Codable {
    let id: UUID
    let date: Date
    let calorieTarget: Double
    let proteinTarget: Double
    let carbTarget: Double
    let fatTarget: Double

    init(from log: DailyLog) {
        self.id = log.id
        self.date = log.date
        self.calorieTarget = log.calorieTarget
        self.proteinTarget = log.proteinTarget
        self.carbTarget = log.carbTarget
        self.fatTarget = log.fatTarget
    }

    func toDailyLog() -> DailyLog {
        return DailyLog(
            date: date,
            calorieTarget: calorieTarget,
            proteinTarget: proteinTarget,
            carbTarget: carbTarget,
            fatTarget: fatTarget
        )
    }
}

struct FoodEntryBackup: Codable {
    let id: UUID
    let productId: UUID?
    let dailyLogId: UUID?
    let customFoodName: String?
    let amount: Double
    let unit: String
    let timestamp: Date
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let sugar: Double
    let naturalSugar: Double
    let addedSugar: Double
    let fibre: Double
    let sodium: Double
    let aiGenerated: Bool
    let aiPrompt: String?

    init(from entry: FoodEntry) {
        self.id = entry.id
        self.productId = entry.product?.id
        self.dailyLogId = entry.dailyLog?.id
        self.customFoodName = entry.customFoodName
        self.amount = entry.amount
        self.unit = entry.unit
        self.timestamp = entry.timestamp
        self.calories = entry.calories
        self.protein = entry.protein
        self.carbohydrates = entry.carbohydrates
        self.fat = entry.fat
        self.sugar = entry.sugar
        self.naturalSugar = entry.naturalSugar
        self.addedSugar = entry.addedSugar
        self.fibre = entry.fibre
        self.sodium = entry.sodium
        self.aiGenerated = entry.aiGenerated
        self.aiPrompt = entry.aiPrompt
    }

    func toFoodEntry() -> FoodEntry {
        return FoodEntry(
            product: nil,
            customFoodName: customFoodName,
            amount: amount,
            unit: unit,
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            sugar: sugar,
            naturalSugar: naturalSugar,
            addedSugar: addedSugar,
            fibre: fibre,
            sodium: sodium,
            aiGenerated: aiGenerated,
            aiPrompt: aiPrompt
        )
    }
}

struct AITemplateBackup: Codable {
    let id: UUID
    let name: String
    let amount: Double
    let unit: String
    let weightInGrams: Double
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let sugar: Double
    let naturalSugar: Double
    let addedSugar: Double
    let fibre: Double
    let sodium: Double
    let aiPrompt: String?
    let useCount: Int
    let lastUsed: Date

    // Vitamins
    let vitaminA: Double?
    let vitaminC: Double?
    let vitaminD: Double?
    let vitaminE: Double?
    let vitaminK: Double?
    let vitaminB1: Double?
    let vitaminB2: Double?
    let vitaminB3: Double?
    let vitaminB5: Double?
    let vitaminB6: Double?
    let vitaminB7: Double?
    let vitaminB12: Double?
    let folate: Double?

    // Minerals
    let calcium: Double?
    let iron: Double?
    let zinc: Double?
    let magnesium: Double?
    let potassium: Double?
    let phosphorus: Double?
    let selenium: Double?
    let copper: Double?
    let manganese: Double?
    let chromium: Double?
    let molybdenum: Double?
    let iodine: Double?
    let chloride: Double?

    init(from template: AIFoodTemplate) {
        self.id = template.id
        self.name = template.name
        self.amount = template.amount
        self.unit = template.unit
        self.weightInGrams = template.weightInGrams
        self.calories = template.calories
        self.protein = template.protein
        self.carbohydrates = template.carbohydrates
        self.fat = template.fat
        self.sugar = template.sugar
        self.naturalSugar = template.naturalSugar
        self.addedSugar = template.addedSugar
        self.fibre = template.fibre
        self.sodium = template.sodium
        self.aiPrompt = template.aiPrompt
        self.useCount = template.useCount
        self.lastUsed = template.lastUsed
        self.vitaminA = template.vitaminA
        self.vitaminC = template.vitaminC
        self.vitaminD = template.vitaminD
        self.vitaminE = template.vitaminE
        self.vitaminK = template.vitaminK
        self.vitaminB1 = template.vitaminB1
        self.vitaminB2 = template.vitaminB2
        self.vitaminB3 = template.vitaminB3
        self.vitaminB5 = template.vitaminB5
        self.vitaminB6 = template.vitaminB6
        self.vitaminB7 = template.vitaminB7
        self.vitaminB12 = template.vitaminB12
        self.folate = template.folate
        self.calcium = template.calcium
        self.iron = template.iron
        self.zinc = template.zinc
        self.magnesium = template.magnesium
        self.potassium = template.potassium
        self.phosphorus = template.phosphorus
        self.selenium = template.selenium
        self.copper = template.copper
        self.manganese = template.manganese
        self.chromium = template.chromium
        self.molybdenum = template.molybdenum
        self.iodine = template.iodine
        self.chloride = template.chloride
    }

    func toAIFoodTemplate() -> AIFoodTemplate {
        let template = AIFoodTemplate(
            name: name,
            amount: amount,
            unit: unit,
            weightInGrams: weightInGrams,
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            sugar: sugar,
            naturalSugar: naturalSugar,
            addedSugar: addedSugar,
            fibre: fibre,
            sodium: sodium,
            aiPrompt: aiPrompt
        )
        template.useCount = useCount
        template.vitaminA = vitaminA
        template.vitaminC = vitaminC
        template.vitaminD = vitaminD
        template.vitaminE = vitaminE
        template.vitaminK = vitaminK
        template.vitaminB1 = vitaminB1
        template.vitaminB2 = vitaminB2
        template.vitaminB3 = vitaminB3
        template.vitaminB5 = vitaminB5
        template.vitaminB6 = vitaminB6
        template.vitaminB7 = vitaminB7
        template.vitaminB12 = vitaminB12
        template.folate = folate
        template.calcium = calcium
        template.iron = iron
        template.zinc = zinc
        template.magnesium = magnesium
        template.potassium = potassium
        template.phosphorus = phosphorus
        template.selenium = selenium
        template.copper = copper
        template.manganese = manganese
        template.chromium = chromium
        template.molybdenum = molybdenum
        template.iodine = iodine
        template.chloride = chloride
        return template
    }
}

// MARK: - Document Type for File Export/Import

struct CalorieTrackerBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
