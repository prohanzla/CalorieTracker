// OpenAIService.swift - OpenAI ChatGPT API integration for nutrition parsing
// Made by mpcode

import Foundation
import UIKit

// MARK: - OpenAI API Response Models
struct OpenAIResponse: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [OpenAIChoice]?
    let usage: OpenAIUsage?
    let error: OpenAIError?
}

struct OpenAIChoice: Codable {
    let index: Int
    let message: OpenAIMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String?
}

struct OpenAIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct OpenAIError: Codable {
    let message: String
    let type: String?
    let code: String?
}

// MARK: - OpenAI API Service
@Observable
class OpenAIService: AIServiceProtocol {
    let provider: AIProvider = .openAI
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o-mini"  // Cost-effective model with vision

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
            "naturalSugar": null (only for whole fruits/vegetables, most labels don't have this),
            "addedSugar": number in grams (per 100g) or null,
            "sodium": number in mg (per 100g) or null,
            "cholesterol": number in mg (per 100g) or null,
            "vitaminA": number in mcg (per 100g) or null,
            "vitaminC": number in mg (per 100g) or null,
            "vitaminD": number in mcg (per 100g) or null,
            "vitaminE": number in mg (per 100g) or null,
            "vitaminK": number in mcg (per 100g) or null,
            "vitaminB1": number in mg (per 100g) or null (thiamin),
            "vitaminB2": number in mg (per 100g) or null (riboflavin),
            "vitaminB3": number in mg (per 100g) or null (niacin),
            "vitaminB5": number in mg (per 100g) or null (pantothenic acid),
            "vitaminB6": number in mg (per 100g) or null,
            "vitaminB7": number in mcg (per 100g) or null (biotin),
            "vitaminB12": number in mcg (per 100g) or null,
            "folate": number in mcg (per 100g) or null (folic acid),
            "calcium": number in mg (per 100g) or null,
            "iron": number in mg (per 100g) or null,
            "potassium": number in mg (per 100g) or null,
            "magnesium": number in mg (per 100g) or null,
            "zinc": number in mg (per 100g) or null,
            "phosphorus": number in mg (per 100g) or null,
            "selenium": number in mcg (per 100g) or null,
            "copper": number in mg (per 100g) or null,
            "manganese": number in mg (per 100g) or null,
            "chromium": number in mcg (per 100g) or null,
            "molybdenum": number in mcg (per 100g) or null,
            "iodine": number in mcg (per 100g) or null,
            "chloride": number in mg (per 100g) or null,
            "confidence": number between 0 and 1
        }

        Use UK spelling (fibre not fiber).
        If the label shows "per serving" or "per portion", you MUST calculate the per 100g values.
        Extract EVERY nutrient visible on the label.
        Return ONLY the JSON, no other text.
        """

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Parse this nutrition label completely and return all nutritional values as JSON. Include all vitamins and minerals visible."
                        ]
                    ]
                ]
            ],
            "max_tokens": 2048,
            "temperature": 0.1
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
            "naturalSugar": null (only for whole fruits/vegetables),
            "addedSugar": number in grams (per 100g) or null,
            "sodium": number in mg (per 100g) or null,
            "cholesterol": number in mg (per 100g) or null,
            "vitaminA": number in mcg (per 100g) or null,
            "vitaminC": number in mg (per 100g) or null,
            "vitaminD": number in mcg (per 100g) or null,
            "vitaminE": number in mg (per 100g) or null,
            "vitaminK": number in mcg (per 100g) or null,
            "vitaminB1": number in mg (per 100g) or null (thiamin),
            "vitaminB2": number in mg (per 100g) or null (riboflavin),
            "vitaminB3": number in mg (per 100g) or null (niacin),
            "vitaminB5": number in mg (per 100g) or null (pantothenic acid),
            "vitaminB6": number in mg (per 100g) or null,
            "vitaminB7": number in mcg (per 100g) or null (biotin),
            "vitaminB12": number in mcg (per 100g) or null,
            "folate": number in mcg (per 100g) or null (folic acid),
            "calcium": number in mg (per 100g) or null,
            "iron": number in mg (per 100g) or null,
            "potassium": number in mg (per 100g) or null,
            "magnesium": number in mg (per 100g) or null,
            "zinc": number in mg (per 100g) or null,
            "phosphorus": number in mg (per 100g) or null,
            "selenium": number in mcg (per 100g) or null,
            "copper": number in mg (per 100g) or null,
            "manganese": number in mg (per 100g) or null,
            "chromium": number in mcg (per 100g) or null,
            "molybdenum": number in mcg (per 100g) or null,
            "iodine": number in mcg (per 100g) or null,
            "chloride": number in mg (per 100g) or null,
            "confidence": number between 0 and 1
        }
        Use UK spelling (fibre not fiber).
        Extract EVERY nutrient visible including pantothenic acid (B5), biotin (B7), chromium, molybdenum, iodine, and chloride.
        Return ONLY the JSON, no other text.
        """

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Parse this nutrition label completely and return all nutritional values as JSON."
                        ]
                    ]
                ]
            ],
            "max_tokens": 2048,
            "temperature": 0.1
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
            "model": "gpt-4o-mini",  // Text-only, use cheaper model
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 1024,
            "temperature": 0.3
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
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 1024,
            "temperature": 0.3
        ]

        let response = try await makeRequest(body: requestBody)
        return try parseVitaminResponse(response)
    }

    private func parseVitaminResponse(_ response: OpenAIResponse) throws -> VitaminAnalysisResult {
        guard let choice = response.choices?.first,
              let text = choice.message.content else {
            throw AIServiceError.parsingFailed
        }

        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.parsingFailed
        }

        return try JSONDecoder().decode(VitaminAnalysisResult.self, from: jsonData)
    }

    // MARK: - Private Helpers
    private func makeRequest(body: [String: Any]) async throws -> OpenAIResponse {
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        // Check for API errors
        if let error = openAIResponse.error {
            if error.code == "invalid_api_key" {
                throw AIServiceError.invalidAPIKey
            }
            if error.code == "rate_limit_exceeded" {
                throw AIServiceError.rateLimited
            }
            if error.code == "insufficient_quota" {
                throw AIServiceError.quotaExceeded
            }
            throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: error.message)
        }

        if httpResponse.statusCode == 401 {
            throw AIServiceError.invalidAPIKey
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        return openAIResponse
    }

    private func parseNutritionResponse(_ response: OpenAIResponse) throws -> ParsedNutrition {
        guard let choice = response.choices?.first,
              let text = choice.message.content else {
            throw AIServiceError.parsingFailed
        }

        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.parsingFailed
        }

        return try JSONDecoder().decode(ParsedNutrition.self, from: jsonData)
    }

    private func parseFullNutritionResponse(_ response: OpenAIResponse) throws -> ParsedNutritionFull {
        guard let choice = response.choices?.first,
              let text = choice.message.content else {
            throw AIServiceError.parsingFailed
        }

        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.parsingFailed
        }

        return try JSONDecoder().decode(ParsedNutritionFull.self, from: jsonData)
    }

    private func parseQuickFoodResponse(_ response: OpenAIResponse) throws -> QuickFoodEstimate {
        guard let choice = response.choices?.first,
              let text = choice.message.content else {
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
