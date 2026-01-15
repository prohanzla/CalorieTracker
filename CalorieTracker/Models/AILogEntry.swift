// AILogEntry.swift - Model for storing AI API responses for debugging/review
// Made by mpcode

import Foundation
import SwiftData

@Model
final class AILogEntry {
    // CloudKit requires default values for all non-optional properties
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var requestType: String = ""  // "vitamin_analysis", "food_estimate", "nutrition_label"
    var provider: String = ""     // "Claude", "Gemini", "ChatGPT"
    var input: String = ""        // The input sent to AI (food list, prompt, etc.)
    var output: String = ""       // The raw JSON or text response
    var success: Bool = false        // Whether the request was successful
    var errorMessage: String?

    init(
        requestType: String,
        provider: String,
        input: String,
        output: String,
        success: Bool = true,
        errorMessage: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.requestType = requestType
        self.provider = provider
        self.input = input
        self.output = output
        self.success = success
        self.errorMessage = errorMessage
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var requestTypeIcon: String {
        switch requestType {
        case "vitamin_analysis": return "pill.fill"
        case "food_estimate": return "fork.knife"
        case "nutrition_label": return "doc.text.viewfinder"
        default: return "brain.head.profile"
        }
    }

    var requestTypeDisplayName: String {
        switch requestType {
        case "vitamin_analysis": return "Vitamin Analysis"
        case "food_estimate": return "Food Estimate"
        case "nutrition_label": return "Label Scan"
        default: return requestType
        }
    }
}
