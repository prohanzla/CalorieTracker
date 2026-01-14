// AIServiceProtocol.swift - Unified protocol for AI nutrition parsing services
// Made by mpcode

import Foundation
import UIKit

// MARK: - AI Provider Enum
enum AIProvider: String, CaseIterable, Codable {
    case claude = "Claude"
    case gemini = "Gemini"
    case openAI = "ChatGPT"

    var displayName: String {
        rawValue
    }

    var iconName: String {
        switch self {
        case .claude: return "brain.head.profile"
        case .gemini: return "sparkles"
        case .openAI: return "bubble.left.and.bubble.right"
        }
    }

    var description: String {
        switch self {
        case .claude: return "Anthropic Claude - Excellent at detailed analysis"
        case .gemini: return "Google Gemini - Free tier (text only, images limited)"
        case .openAI: return "OpenAI ChatGPT - Most popular AI"
        }
    }

    var shortName: String {
        switch self {
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .openAI: return "GPT"
        }
    }

    var apiKeyPrefix: String {
        switch self {
        case .claude: return "sk-ant-"
        case .gemini: return "AI"  // Gemini keys start with AIza
        case .openAI: return "sk-"
        }
    }

    var consoleURL: URL {
        switch self {
        case .claude: return URL(string: "https://console.anthropic.com/")!
        case .gemini: return URL(string: "https://aistudio.google.com/app/apikey")!
        case .openAI: return URL(string: "https://platform.openai.com/api-keys")!
        }
    }

    var apiKeyStorageKey: String {
        switch self {
        case .claude: return "claude_api_key"
        case .gemini: return "gemini_api_key"
        case .openAI: return "openai_api_key"
        }
    }
}

// MARK: - Vitamin Analysis Result
struct VitaminAnalysisResult: Codable {
    var vitaminA: Double?      // mcg
    var vitaminC: Double?      // mg
    var vitaminD: Double?      // mcg
    var vitaminE: Double?      // mg
    var vitaminK: Double?      // mcg
    var vitaminB1: Double?     // mg (Thiamine)
    var vitaminB2: Double?     // mg (Riboflavin)
    var vitaminB3: Double?     // mg (Niacin)
    var vitaminB6: Double?     // mg
    var vitaminB12: Double?    // mcg
    var folate: Double?        // mcg
    var calcium: Double?       // mg
    var iron: Double?          // mg
    var zinc: Double?          // mg
    var magnesium: Double?     // mg
    var potassium: Double?     // mg
    var phosphorus: Double?    // mg
    var selenium: Double?      // mcg
    var copper: Double?        // mg
    var manganese: Double?     // mg
    var sodium: Double?        // mg

    // Source foods for each vitamin (for display in logs)
    var vitaminASources: String?
    var vitaminCSources: String?
    var vitaminDSources: String?
    var vitaminESources: String?
    var vitaminKSources: String?
    var vitaminB1Sources: String?
    var vitaminB2Sources: String?
    var vitaminB3Sources: String?
    var vitaminB6Sources: String?
    var vitaminB12Sources: String?
    var folateSources: String?
    var calciumSources: String?
    var ironSources: String?
    var zincSources: String?
    var magnesiumSources: String?
    var potassiumSources: String?
    var phosphorusSources: String?
    var seleniumSources: String?
    var copperSources: String?
    var manganeseSources: String?
    var sodiumSources: String?
}

// MARK: - AI Service Protocol
protocol AIServiceProtocol {
    var provider: AIProvider { get }
    var apiKey: String { get set }
    var isConfigured: Bool { get }

    func parseNutritionLabel(image: UIImage) async throws -> ParsedNutrition
    func parseNutritionLabelFull(image: UIImage) async throws -> ParsedNutritionFull
    func estimateFromPrompt(_ prompt: String) async throws -> QuickFoodEstimate
    func analyzeVitamins(foods: [String]) async throws -> VitaminAnalysisResult
}

// MARK: - AI Service Error
enum AIServiceError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidAPIKey
    case invalidResponse
    case imageProcessingFailed
    case parsingFailed
    case rateLimited
    case quotaExceeded
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "API key not configured. Please add your API key in Settings."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidAPIKey:
            return "Invalid API key. Please check your API key."
        case .invalidResponse:
            return "Invalid response from API."
        case .imageProcessingFailed:
            return "Failed to process image."
        case .parsingFailed:
            return "Failed to parse nutrition data from response."
        case .rateLimited:
            return "Rate limited. Please wait a moment and try again."
        case .quotaExceeded:
            return "API quota exceeded. Please check your billing."
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}

// MARK: - AI Service Manager
@Observable
class AIServiceManager {
    static let shared = AIServiceManager()

    private let claudeService = ClaudeAPIService()
    private let geminiService = GeminiAPIService()
    private let openAIService = OpenAIService()

    // Stored property to trigger @Observable updates
    private var _selectedProvider: AIProvider

    var selectedProvider: AIProvider {
        get { _selectedProvider }
        set {
            _selectedProvider = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: "selected_ai_provider")
        }
    }

    private init() {
        // Load from UserDefaults on init
        if let stored = UserDefaults.standard.string(forKey: "selected_ai_provider"),
           let provider = AIProvider(rawValue: stored) {
            _selectedProvider = provider
        } else {
            _selectedProvider = .claude
        }
    }

    var currentService: any AIServiceProtocol {
        switch selectedProvider {
        case .claude: return claudeService
        case .gemini: return geminiService
        case .openAI: return openAIService
        }
    }

    var isConfigured: Bool {
        currentService.isConfigured
    }

    func service(for provider: AIProvider) -> any AIServiceProtocol {
        switch provider {
        case .claude: return claudeService
        case .gemini: return geminiService
        case .openAI: return openAIService
        }
    }

    func getAPIKey(for provider: AIProvider) -> String {
        UserDefaults.standard.string(forKey: provider.apiKeyStorageKey) ?? ""
    }

    func setAPIKey(_ key: String, for provider: AIProvider) {
        UserDefaults.standard.set(key, forKey: provider.apiKeyStorageKey)
    }

    func isConfigured(provider: AIProvider) -> Bool {
        !getAPIKey(for: provider).isEmpty
    }

    // Convenience methods that use the current service
    func parseNutritionLabel(image: UIImage) async throws -> ParsedNutrition {
        try await currentService.parseNutritionLabel(image: image)
    }

    func parseNutritionLabelFull(image: UIImage) async throws -> ParsedNutritionFull {
        try await currentService.parseNutritionLabelFull(image: image)
    }

    func estimateFromPrompt(_ prompt: String) async throws -> QuickFoodEstimate {
        try await currentService.estimateFromPrompt(prompt)
    }

    func analyzeVitamins(foods: [String]) async throws -> VitaminAnalysisResult {
        try await currentService.analyzeVitamins(foods: foods)
    }
}
