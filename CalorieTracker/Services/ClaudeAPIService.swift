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

// MARK: - Nutrition Data from AI
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
    let confidence: Double?  // AI's confidence in the parsing (0-1)
}

// MARK: - Quick Food Entry from Natural Language
struct QuickFoodEstimate: Codable {
    let foodName: String
    let amount: Double
    let unit: String
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let confidence: Double
    let notes: String?
}

// MARK: - Claude API Service
@Observable
class ClaudeAPIService {
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    private let model = "claude-sonnet-4-20250514"

    // Store API key securely - in production use Keychain
    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "claude_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "claude_api_key") }
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    // MARK: - Parse Nutrition Label Image
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
        Return ONLY a valid JSON object with these fields (use null for missing values):
        {
            "productName": "string or null",
            "servingSize": number or null,
            "servingSizeUnit": "g" or "ml" or null,
            "calories": number,
            "protein": number or null,
            "carbohydrates": number or null,
            "fat": number or null,
            "saturatedFat": number or null,
            "fibre": number or null,
            "sugar": number or null,
            "sodium": number or null,
            "vitaminA": number or null,
            "vitaminC": number or null,
            "vitaminD": number or null,
            "calcium": number or null,
            "iron": number or null,
            "confidence": number between 0 and 1
        }
        Use UK spelling (fibre not fiber). All values should be per serving.
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

    // MARK: - Estimate Nutrition from Natural Language
    func estimateFromPrompt(_ prompt: String) async throws -> QuickFoodEstimate {
        guard isConfigured else {
            throw ClaudeAPIError.notConfigured
        }

        let systemPrompt = """
        You are a nutrition estimation assistant. The user will describe food they ate in natural language.
        Estimate the nutritional content based on average values for that food.
        Return ONLY a valid JSON object:
        {
            "foodName": "descriptive name",
            "amount": number,
            "unit": "piece", "g", "ml", "cup", etc.,
            "calories": number,
            "protein": number in grams,
            "carbohydrates": number in grams,
            "fat": number in grams,
            "confidence": number between 0 and 1,
            "notes": "any relevant notes or assumptions" or null
        }
        Use realistic average nutritional values. Be conservative with estimates.
        Example: "one apple" → ~95 calories, 0.5g protein, 25g carbs, 0.3g fat
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 512,
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

        // Extract JSON from response (might be wrapped in markdown code blocks)
        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeAPIError.parsingFailed
        }

        return try JSONDecoder().decode(ParsedNutrition.self, from: jsonData)
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
        // Remove markdown code blocks if present
        var cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Find JSON object boundaries
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
