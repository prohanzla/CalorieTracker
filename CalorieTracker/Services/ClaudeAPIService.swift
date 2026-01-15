// ClaudeAPIService.swift - Claude API integration for nutrition parsing
// Made by mpcode

import Foundation
import UIKit

// MARK: - Claude API Response Models
struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stopReason: String?
    let usage: Usage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model, usage
        case stopReason = "stop_reason"
    }
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
}

struct Usage: Codable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Nutrition Data from AI (Basic)
struct ParsedNutrition: Codable {
    let productName: String?
    let servingSize: Double?
    let servingSizeUnit: String?
    let calories: Double
    let protein: Double?
    let carbohydrates: Double?
    let fat: Double?
    let saturatedFat: Double?
    let fibre: Double?
    let sugar: Double?
    let sodium: Double?
    let vitaminA: Double?
    let vitaminC: Double?
    let vitaminD: Double?
    let calcium: Double?
    let iron: Double?
    let confidence: Double?
}

// MARK: - Full Nutrition Data from AI (All vitamins & minerals)
struct ParsedNutritionFull: Codable {
    let productName: String?
    let servingSize: Double?
    let servingSizeUnit: String?
    let calories: Double

    // Main macros
    let protein: Double?
    let carbohydrates: Double?
    let fat: Double?
    let saturatedFat: Double?
    let transFat: Double?
    let fibre: Double?
    let sugar: Double?
    let sodium: Double?
    let cholesterol: Double?

    // Vitamins
    let vitaminA: Double?
    let vitaminC: Double?
    let vitaminD: Double?
    let vitaminE: Double?
    let vitaminK: Double?
    let vitaminB1: Double?
    let vitaminB2: Double?
    let vitaminB3: Double?
    let vitaminB6: Double?
    let vitaminB12: Double?
    let folate: Double?

    // Minerals
    let calcium: Double?
    let iron: Double?
    let potassium: Double?
    let magnesium: Double?
    let zinc: Double?
    let phosphorus: Double?
    let selenium: Double?
    let copper: Double?
    let manganese: Double?

    let confidence: Double?
}

// MARK: - Quick Food Entry from Natural Language (includes vitamins)
struct QuickFoodEstimate: Codable {
    let foodName: String
    let emoji: String?       // Single emoji representing the food (e.g., "🍊" for mandarin)
    let amount: Double
    let unit: String
    let weightInGrams: Double  // Actual weight in grams (e.g., 88g for 1 medium mandarin)
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let sugar: Double?
    let fibre: Double?
    let sodium: Double?  // in mg

    // Vitamins (per the amount specified)
    let vitaminA: Double?      // mcg
    let vitaminC: Double?      // mg
    let vitaminD: Double?      // mcg
    let vitaminE: Double?      // mg
    let vitaminK: Double?      // mcg
    let vitaminB1: Double?     // mg
    let vitaminB2: Double?     // mg
    let vitaminB3: Double?     // mg
    let vitaminB6: Double?     // mg
    let vitaminB12: Double?    // mcg
    let folate: Double?        // mcg

    // Minerals (per the amount specified)
    let calcium: Double?       // mg
    let iron: Double?          // mg
    let zinc: Double?          // mg
    let magnesium: Double?     // mg
    let potassium: Double?     // mg
    let phosphorus: Double?    // mg
    let selenium: Double?      // mcg
    let copper: Double?        // mg
    let manganese: Double?     // mg

    let confidence: Double
    let notes: String?
}

// MARK: - Vitamin Analysis Response
struct VitaminAnalysis: Codable {
    let vitaminA: VitaminInfo?
    let vitaminC: VitaminInfo?
    let vitaminD: VitaminInfo?
    let vitaminE: VitaminInfo?
    let vitaminK: VitaminInfo?
    let vitaminB1: VitaminInfo?
    let vitaminB2: VitaminInfo?
    let vitaminB6: VitaminInfo?
    let vitaminB12: VitaminInfo?
    let folate: VitaminInfo?
    let calcium: VitaminInfo?
    let iron: VitaminInfo?
    let magnesium: VitaminInfo?
    let potassium: VitaminInfo?
    let zinc: VitaminInfo?
    let summary: String
    let recommendations: [String]?
}

struct VitaminInfo: Codable {
    let amount: Double
    let unit: String
    let percentDailyValue: Double
    let status: String  // "adequate", "low", "deficient", "excess"
}

// MARK: - Claude API Service
@Observable
class ClaudeAPIService: AIServiceProtocol {
    let provider: AIProvider = .claude
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    private let model = "claude-sonnet-4-20250514"

    // Store API key securely - in production use Keychain
    var apiKey: String {
        get { UserDefaults.standard.string(forKey: provider.apiKeyStorageKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: provider.apiKeyStorageKey) }
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    // MARK: - Parse Nutrition Label Image (Basic)
    func parseNutritionLabel(image: UIImage) async throws -> ParsedNutrition {
        guard isConfigured else {
            throw ClaudeAPIError.notConfigured
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ClaudeAPIError.imageProcessingFailed
        }

        let base64Image = imageData.base64EncodedString()
        let mediaType = "image/jpeg"

        let systemPrompt = """
        You are a nutrition label parser. Analyse the nutrition label image and extract all nutritional information.

        IMPORTANT: ALL values must be returned PER 100g (not per serving). If the label shows values per serving, calculate and convert them to per 100g values.

        Return ONLY a valid JSON object with these fields (use null for missing values):
        {
            "productName": "string or null",
            "servingSize": 100 (always return 100 as we store per 100g),
            "servingSizeUnit": "g",
            "calories": number (per 100g),
            "protein": number in grams (per 100g) or null,
            "carbohydrates": number in grams (per 100g) or null,
            "fat": number in grams (per 100g) or null,
            "saturatedFat": number in grams (per 100g) or null,
            "fibre": number in grams (per 100g) or null,
            "sugar": number in grams (per 100g) or null,
            "sodium": number in mg (per 100g) or null,
            "vitaminA": number or null,
            "vitaminC": number or null,
            "vitaminD": number or null,
            "calcium": number in mg (per 100g) or null,
            "iron": number in mg (per 100g) or null,
            "confidence": number between 0 and 1
        }
        Use UK spelling (fibre not fiber).
        If the label shows "per serving", calculate and return per 100g values.
        If you cannot read certain values, set confidence lower and use null.
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": mediaType,
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Parse this nutrition label and return the JSON."
                        ]
                    ]
                ]
            ]
        ]

        let response = try await makeRequest(body: requestBody)
        return try parseNutritionResponse(response)
    }

    // MARK: - Parse Nutrition Label Image (Full - All Vitamins & Minerals)
    func parseNutritionLabelFull(image: UIImage) async throws -> ParsedNutritionFull {
        guard isConfigured else {
            throw ClaudeAPIError.notConfigured
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ClaudeAPIError.imageProcessingFailed
        }

        let base64Image = imageData.base64EncodedString()
        let mediaType = "image/jpeg"

        let systemPrompt = """
        You are a nutrition label parser. Analyse the nutrition label image and extract ALL nutritional information including all vitamins and minerals.

        IMPORTANT: ALL values must be returned PER 100g (not per serving). If the label shows values per serving, calculate and convert them to per 100g values.

        Return ONLY a valid JSON object with these fields (use null for missing/unreadable values):
        {
            "productName": "string or null",
            "servingSize": 100 (always return 100 as we store per 100g),
            "servingSizeUnit": "g",
            "calories": number (per 100g),
            "protein": number in grams (per 100g) or null,
            "carbohydrates": number in grams (per 100g) or null,
            "fat": number in grams (per 100g) or null,
            "saturatedFat": number in grams (per 100g) or null,
            "transFat": number in grams (per 100g) or null,
            "fibre": number in grams (per 100g) or null,
            "sugar": number in grams (per 100g) or null,
            "sodium": number in mg (per 100g) or null,
            "cholesterol": number in mg (per 100g) or null,
            "vitaminA": number (percentage daily value per 100g) or null,
            "vitaminC": number (percentage daily value per 100g) or null,
            "vitaminD": number (percentage daily value per 100g) or null,
            "vitaminE": number (percentage daily value per 100g) or null,
            "vitaminK": number (percentage daily value per 100g) or null,
            "vitaminB1": number (percentage daily value per 100g) or null,
            "vitaminB2": number (percentage daily value per 100g) or null,
            "vitaminB3": number (percentage daily value per 100g) or null,
            "vitaminB6": number (percentage daily value per 100g) or null,
            "vitaminB12": number (percentage daily value per 100g) or null,
            "folate": number (percentage daily value per 100g) or null,
            "calcium": number in mg (per 100g) or null,
            "iron": number in mg (per 100g) or null,
            "potassium": number in mg (per 100g) or null,
            "magnesium": number in mg (per 100g) or null,
            "zinc": number in mg (per 100g) or null,
            "phosphorus": number in mg (per 100g) or null,
            "selenium": number in mcg (per 100g) or null,
            "copper": number in mg (per 100g) or null,
            "manganese": number in mg (per 100g) or null,
            "confidence": number between 0 and 1
        }

        Use UK spelling (fibre not fiber).
        If the label shows "per serving" or "per portion", you MUST calculate the per 100g values.
        For example: if serving size is 30g with 150 calories, then per 100g = 500 calories.
        Extract EVERY nutrient visible on the label. If a value shows percentage, use the percentage number.
        If you cannot read certain values, set confidence lower and use null for those fields.
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": mediaType,
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Parse this nutrition label completely and return all nutritional values as JSON. Include all vitamins and minerals visible."
                        ]
                    ]
                ]
            ]
        ]

        let response = try await makeRequest(body: requestBody)
        return try parseFullNutritionResponse(response)
    }

    // MARK: - Estimate Nutrition from Natural Language
    func estimateFromPrompt(_ prompt: String) async throws -> QuickFoodEstimate {
        guard isConfigured else {
            throw ClaudeAPIError.notConfigured
        }

        let systemPrompt = """
        You are a nutrition estimation assistant. The user will describe food they ate in natural language.
        Estimate the COMPLETE nutritional content including all vitamins and minerals based on average values.
        Return ONLY a valid JSON object:
        {
            "foodName": "descriptive name",
            "emoji": "single food emoji like 🍎🍌🍊🥗🍕🥚🥛🍞🥩🐟 etc",
            "amount": number,
            "unit": "piece", "g", "ml", "cup", etc.,
            "weightInGrams": number (REQUIRED: actual weight in grams, e.g., 88 for 1 medium mandarin, 250 for 250g beef),
            "calories": number,
            "protein": number in grams,
            "carbohydrates": number in grams,
            "fat": number in grams,
            "sugar": number in grams or null,
            "fibre": number in grams or null,
            "sodium": number in mg or null,
            "vitaminA": number in mcg or null,
            "vitaminC": number in mg or null,
            "vitaminD": number in mcg or null,
            "vitaminE": number in mg or null,
            "vitaminK": number in mcg or null,
            "vitaminB1": number in mg or null,
            "vitaminB2": number in mg or null,
            "vitaminB3": number in mg or null,
            "vitaminB6": number in mg or null,
            "vitaminB12": number in mcg or null,
            "folate": number in mcg or null,
            "calcium": number in mg or null,
            "iron": number in mg or null,
            "zinc": number in mg or null,
            "magnesium": number in mg or null,
            "potassium": number in mg or null,
            "phosphorus": number in mg or null,
            "selenium": number in mcg or null,
            "copper": number in mg or null,
            "manganese": number in mg or null,
            "confidence": number between 0 and 1,
            "notes": "any relevant notes or assumptions" or null
        }
        Use realistic average nutritional values from USDA/NHS databases. Be conservative with estimates.
        Use UK spelling (fibre not fiber).
        IMPORTANT: Include vitamin and mineral estimates for ALL foods - these are essential for tracking.
        IMPORTANT: Choose the most appropriate single emoji that best represents the food visually.
        IMPORTANT: Always provide weightInGrams - the actual weight even for "piece" units (e.g., 1 mandarin = 88g, 1 apple = 182g).
        Example: "1 mandarin" → emoji: "🍊", amount: 1, unit: "piece", weightInGrams: 88, calories: 47
        Example: "250g beef" → emoji: "🥩", amount: 250, unit: "g", weightInGrams: 250, calories: 625
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,  // Increased for vitamin data
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        let response = try await makeRequest(body: requestBody)
        return try parseQuickFoodResponse(response)
    }

    // MARK: - Analyze Vitamins from Food List
    func analyzeVitamins(foods: [String]) async throws -> VitaminAnalysisResult {
        guard isConfigured else {
            throw ClaudeAPIError.notConfigured
        }

        let foodList = foods.joined(separator: "\n- ")

        let systemPrompt = """
        You are a nutrition expert. The user will provide a list of foods they ate today with amounts.
        Analyse these foods and estimate the TOTAL vitamins and minerals consumed.

        Return ONLY a valid JSON object with these fields (use estimated values based on typical nutritional content):
        {
            "vitaminA": number in mcg or null,
            "vitaminASources": "from food1, food2" or null,
            "vitaminC": number in mg or null,
            "vitaminCSources": "from food1, food2" or null,
            "vitaminD": number in mcg or null,
            "vitaminDSources": "from food1, food2" or null,
            "vitaminE": number in mg or null,
            "vitaminESources": "from food1, food2" or null,
            "vitaminK": number in mcg or null,
            "vitaminKSources": "from food1, food2" or null,
            "vitaminB1": number in mg or null,
            "vitaminB1Sources": "from food1, food2" or null,
            "vitaminB2": number in mg or null,
            "vitaminB2Sources": "from food1, food2" or null,
            "vitaminB3": number in mg or null,
            "vitaminB3Sources": "from food1, food2" or null,
            "vitaminB6": number in mg or null,
            "vitaminB6Sources": "from food1, food2" or null,
            "vitaminB12": number in mcg or null,
            "vitaminB12Sources": "from food1, food2" or null,
            "folate": number in mcg or null,
            "folateSources": "from food1, food2" or null,
            "calcium": number in mg or null,
            "calciumSources": "from food1, food2" or null,
            "iron": number in mg or null,
            "ironSources": "from food1, food2" or null,
            "zinc": number in mg or null,
            "zincSources": "from food1, food2" or null,
            "magnesium": number in mg or null,
            "magnesiumSources": "from food1, food2" or null,
            "potassium": number in mg or null,
            "potassiumSources": "from food1, food2" or null,
            "phosphorus": number in mg or null,
            "phosphorusSources": "from food1, food2" or null,
            "selenium": number in mcg or null,
            "seleniumSources": "from food1, food2" or null,
            "copper": number in mg or null,
            "copperSources": "from food1, food2" or null,
            "manganese": number in mg or null,
            "manganeseSources": "from food1, food2" or null,
            "sodium": number in mg or null,
            "sodiumSources": "from food1, food2" or null
        }

        IMPORTANT: For each vitamin/mineral, include which foods from the list contributed to it in the Sources field.
        Base estimates on standard nutritional databases (USDA, NHS).
        Sum up all the vitamins from all foods listed.
        Be realistic and use average values for typical portions.
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": "Analyse the vitamins and minerals in these foods I ate today:\n- \(foodList)"
                ]
            ]
        ]

        let response = try await makeRequest(body: requestBody)
        return try parseVitaminResponse(response)
    }

    private func parseVitaminResponse(_ response: ClaudeResponse) throws -> VitaminAnalysisResult {
        guard let textContent = response.content.first(where: { $0.type == "text" }),
              let text = textContent.text else {
            throw ClaudeAPIError.parsingFailed
        }

        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeAPIError.parsingFailed
        }

        return try JSONDecoder().decode(VitaminAnalysisResult.self, from: jsonData)
    }

    // MARK: - Private Helpers
    private func makeRequest(body: [String: Any]) async throws -> ClaudeResponse {
        guard let url = URL(string: baseURL) else {
            throw ClaudeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw ClaudeAPIError.invalidAPIKey
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        return try JSONDecoder().decode(ClaudeResponse.self, from: data)
    }

    private func parseNutritionResponse(_ response: ClaudeResponse) throws -> ParsedNutrition {
        guard let textContent = response.content.first(where: { $0.type == "text" }),
              let text = textContent.text else {
            throw ClaudeAPIError.parsingFailed
        }

        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeAPIError.parsingFailed
        }

        return try JSONDecoder().decode(ParsedNutrition.self, from: jsonData)
    }

    private func parseFullNutritionResponse(_ response: ClaudeResponse) throws -> ParsedNutritionFull {
        guard let textContent = response.content.first(where: { $0.type == "text" }),
              let text = textContent.text else {
            throw ClaudeAPIError.parsingFailed
        }

        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeAPIError.parsingFailed
        }

        return try JSONDecoder().decode(ParsedNutritionFull.self, from: jsonData)
    }

    private func parseQuickFoodResponse(_ response: ClaudeResponse) throws -> QuickFoodEstimate {
        guard let textContent = response.content.first(where: { $0.type == "text" }),
              let text = textContent.text else {
            throw ClaudeAPIError.parsingFailed
        }

        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeAPIError.parsingFailed
        }

        return try JSONDecoder().decode(QuickFoodEstimate.self, from: jsonData)
    }

    private func extractJSON(from text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startIndex...endIndex])
        }

        return cleaned
    }
}

// MARK: - Errors
enum ClaudeAPIError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidAPIKey
    case invalidResponse
    case imageProcessingFailed
    case parsingFailed
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "API key not configured. Please add your Claude API key in Settings."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidAPIKey:
            return "Invalid API key. Please check your Claude API key."
        case .invalidResponse:
            return "Invalid response from API."
        case .imageProcessingFailed:
            return "Failed to process image."
        case .parsingFailed:
            return "Failed to parse nutrition data from response."
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}
