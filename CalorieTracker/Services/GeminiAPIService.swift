// GeminiAPIService.swift - Google Gemini API integration for nutrition parsing
// Made by mpcode

import Foundation
import UIKit

// MARK: - Gemini API Response Models
struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
    let error: GeminiError?
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
    let role: String?
}

struct GeminiPart: Codable {
    let text: String?
}

struct GeminiError: Codable {
    let code: Int
    let message: String
    let status: String?
}

// MARK: - Gemini API Service
@Observable
class GeminiAPIService: AIServiceProtocol {
    let provider: AIProvider = .gemini
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let model = "gemini-2.0-flash"  // Free tier model

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
            throw AIServiceError.notConfigured
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AIServiceError.imageProcessingFailed
        }

        let base64Image = imageData.base64EncodedString()

        let systemPrompt = """
        You are a nutrition label parser. Analyse the nutrition label image and extract all nutritional information.

        IMPORTANT: ALL values must be returned PER 100g (not per serving). If the label shows values per serving, calculate and convert them to per 100g values.

        Return ONLY a valid JSON object with these fields (use null for missing values):
        {
            "productName": "string or null",
            "servingSize": 100,
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
        Return ONLY the JSON, no other text.
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": systemPrompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        ["text": "Parse this nutrition label and return the JSON."]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 1024
            ]
        ]

        let response = try await makeRequest(body: requestBody)
        return try parseNutritionResponse(response)
    }

    // MARK: - Parse Nutrition Label Image (Full)
    func parseNutritionLabelFull(image: UIImage) async throws -> ParsedNutritionFull {
        guard isConfigured else {
            throw AIServiceError.notConfigured
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AIServiceError.imageProcessingFailed
        }

        let base64Image = imageData.base64EncodedString()

        let systemPrompt = """
        You are a nutrition label parser. Analyse the nutrition label image and extract ALL nutritional information including all vitamins and minerals.

        IMPORTANT: ALL values must be returned PER 100g (not per serving). If the label shows values per serving, calculate and convert them to per 100g values.

        Return ONLY a valid JSON object with these fields (use null for missing/unreadable values):
        {
            "productName": "string or null",
            "servingSize": 100,
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
        Return ONLY the JSON, no other text.
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": systemPrompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        ["text": "Parse this nutrition label completely and return all nutritional values as JSON."]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 2048
            ]
        ]

        let response = try await makeRequest(body: requestBody)
        return try parseFullNutritionResponse(response)
    }

    // MARK: - Estimate from Prompt
    func estimateFromPrompt(_ prompt: String) async throws -> QuickFoodEstimate {
        guard isConfigured else {
            throw AIServiceError.notConfigured
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
            "sugar": number in grams or null (TOTAL sugar),
            "naturalSugar": number in grams or null (sugar from whole fruits, vegetables, dairy - NATURAL sources),
            "addedSugar": number in grams or null (added/processed sugars from sweets, sodas, processed foods),
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
        Use UK spelling (fibre not fiber).
        IMPORTANT: Include vitamin and mineral estimates for ALL foods - these are essential for tracking.
        IMPORTANT: Choose the most appropriate single emoji that best represents the food visually.
        IMPORTANT: Always provide weightInGrams - the actual weight even for "piece" units (e.g., 1 mandarin = 88g, 1 apple = 182g).
        IMPORTANT: Distinguish between naturalSugar (from whole fruits, veg, dairy) and addedSugar (processed/added).
        - Whole fruits like mandarins, apples = 100% naturalSugar, 0 addedSugar
        - Candy, chocolate, soda = 0 naturalSugar, 100% addedSugar
        - Yogurt with fruit = mixed (estimate the split)
        - Plain dairy (milk, plain yogurt) = naturalSugar (lactose)
        Return ONLY the JSON, no other text.
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": systemPrompt],
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 1024
            ]
        ]

        let response = try await makeRequest(body: requestBody)
        return try parseQuickFoodResponse(response)
    }

    // MARK: - Analyze Vitamins from Food List
    func analyzeVitamins(foods: [String]) async throws -> VitaminAnalysisResult {
        guard isConfigured else {
            throw AIServiceError.notConfigured
        }

        let foodList = foods.joined(separator: "\n- ")

        let prompt = """
        You are a nutrition expert. Analyse these foods and estimate the TOTAL vitamins and minerals consumed.

        Foods eaten today:
        - \(foodList)

        Return ONLY a valid JSON object with these fields (use estimated values):
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
        Return ONLY the JSON, no other text.
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 1024
            ]
        ]

        let response = try await makeRequest(body: requestBody)
        return try parseVitaminResponse(response)
    }

    private func parseVitaminResponse(_ response: GeminiResponse) throws -> VitaminAnalysisResult {
        guard let candidates = response.candidates,
              let firstCandidate = candidates.first,
              let text = firstCandidate.content.parts.first?.text else {
            throw AIServiceError.parsingFailed
        }

        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.parsingFailed
        }

        return try JSONDecoder().decode(VitaminAnalysisResult.self, from: jsonData)
    }

    // MARK: - Private Helpers
    private func makeRequest(body: [String: Any]) async throws -> GeminiResponse {
        let urlString = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            print("🔴 [Gemini] Invalid URL: \(urlString)")
            throw AIServiceError.invalidURL
        }

        print("🟡 [Gemini] Making request to: \(baseURL)/\(model):generateContent")
        print("🟡 [Gemini] API Key prefix: \(String(apiKey.prefix(10)))...")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔴 [Gemini] Invalid response type")
            throw AIServiceError.invalidResponse
        }

        print("🟡 [Gemini] HTTP Status Code: \(httpResponse.statusCode)")

        // Debug: Print raw response
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("🟡 [Gemini] Raw Response: \(rawResponse.prefix(500))...")
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        // Check for API errors
        if let error = geminiResponse.error {
            print("🔴 [Gemini] API Error - Code: \(error.code), Status: \(error.status ?? "nil")")
            print("🔴 [Gemini] API Error Message: \(error.message)")

            if error.code == 400 && error.message.contains("API key") {
                throw AIServiceError.invalidAPIKey
            }
            if error.code == 429 {
                print("🔴 [Gemini] Rate limited! Message: \(error.message)")
                throw AIServiceError.rateLimited
            }
            throw AIServiceError.apiError(statusCode: error.code, message: error.message)
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            print("🔴 [Gemini] Authentication error: \(httpResponse.statusCode)")
            throw AIServiceError.invalidAPIKey
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("🔴 [Gemini] HTTP Error \(httpResponse.statusCode): \(errorMessage)")
            throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        print("🟢 [Gemini] Request successful!")
        return geminiResponse
    }

    private func parseNutritionResponse(_ response: GeminiResponse) throws -> ParsedNutrition {
        guard let candidate = response.candidates?.first,
              let text = candidate.content.parts.first?.text else {
            throw AIServiceError.parsingFailed
        }

        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.parsingFailed
        }

        return try JSONDecoder().decode(ParsedNutrition.self, from: jsonData)
    }

    private func parseFullNutritionResponse(_ response: GeminiResponse) throws -> ParsedNutritionFull {
        guard let candidate = response.candidates?.first,
              let text = candidate.content.parts.first?.text else {
            throw AIServiceError.parsingFailed
        }

        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.parsingFailed
        }

        return try JSONDecoder().decode(ParsedNutritionFull.self, from: jsonData)
    }

    private func parseQuickFoodResponse(_ response: GeminiResponse) throws -> QuickFoodEstimate {
        guard let candidate = response.candidates?.first,
              let text = candidate.content.parts.first?.text else {
            throw AIServiceError.parsingFailed
        }

        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.parsingFailed
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
