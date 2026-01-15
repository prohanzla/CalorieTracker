// FoodEmojiMapper.swift - Centralised food emoji and color mapping
// Made by mpcode

import SwiftUI

/// Centralised utility for mapping food names to emojis and colors
/// Used across DashboardView, HistoryView, AddFoodView, and ProductListView
struct FoodEmojiMapper {

    /// Returns an appropriate emoji for a food name
    /// - Parameters:
    ///   - name: The food name to match
    ///   - productEmoji: Optional emoji from the product (takes priority if set)
    ///   - isAIGenerated: Whether the entry was AI-generated (affects default)
    /// - Returns: A matching emoji string
    static func emoji(for name: String, productEmoji: String? = nil, isAIGenerated: Bool = false) -> String {
        // First check if product has AI-assigned emoji
        if let emoji = productEmoji, !emoji.isEmpty {
            return emoji
        }

        let lowercased = name.lowercased()

        // Fruits
        if lowercased.contains("apple") { return "🍎" }
        if lowercased.contains("banana") { return "🍌" }
        if lowercased.contains("orange") { return "🍊" }
        if lowercased.contains("grape") { return "🍇" }
        if lowercased.contains("strawberr") { return "🍓" }
        if lowercased.contains("watermelon") { return "🍉" }
        if lowercased.contains("peach") { return "🍑" }
        if lowercased.contains("pear") { return "🍐" }
        if lowercased.contains("cherry") { return "🍒" }
        if lowercased.contains("lemon") { return "🍋" }
        if lowercased.contains("mango") { return "🥭" }
        if lowercased.contains("pineapple") { return "🍍" }
        if lowercased.contains("coconut") { return "🥥" }
        if lowercased.contains("kiwi") { return "🥝" }
        if lowercased.contains("blueberr") { return "🫐" }
        if lowercased.contains("avocado") { return "🥑" }

        // Vegetables
        if lowercased.contains("carrot") { return "🥕" }
        if lowercased.contains("broccoli") { return "🥦" }
        if lowercased.contains("corn") { return "🌽" }
        if lowercased.contains("cucumber") { return "🥒" }
        if lowercased.contains("tomato") { return "🍅" }
        if lowercased.contains("potato") { return "🥔" }
        if lowercased.contains("onion") { return "🧅" }
        if lowercased.contains("garlic") { return "🧄" }
        if lowercased.contains("pepper") { return "🌶️" }
        if lowercased.contains("lettuce") || lowercased.contains("salad") { return "🥬" }
        if lowercased.contains("mushroom") { return "🍄" }
        if lowercased.contains("eggplant") || lowercased.contains("aubergine") { return "🍆" }

        // Proteins
        if lowercased.contains("chicken") { return "🍗" }
        if lowercased.contains("beef") || lowercased.contains("steak") { return "🥩" }
        if lowercased.contains("fish") || lowercased.contains("salmon") || lowercased.contains("tuna") { return "🐟" }
        if lowercased.contains("shrimp") || lowercased.contains("prawn") { return "🦐" }
        if lowercased.contains("egg") { return "🥚" }
        if lowercased.contains("bacon") { return "🥓" }

        // Dairy
        if lowercased.contains("milk") { return "🥛" }
        if lowercased.contains("cheese") { return "🧀" }
        if lowercased.contains("yogurt") || lowercased.contains("yoghurt") { return "🥛" }
        if lowercased.contains("butter") { return "🧈" }

        // Grains & Bread
        if lowercased.contains("bread") || lowercased.contains("toast") { return "🍞" }
        if lowercased.contains("rice") { return "🍚" }
        if lowercased.contains("pasta") || lowercased.contains("spaghetti") || lowercased.contains("noodle") { return "🍝" }
        if lowercased.contains("cereal") || lowercased.contains("oat") { return "🥣" }
        if lowercased.contains("croissant") { return "🥐" }
        if lowercased.contains("bagel") { return "🥯" }
        if lowercased.contains("pancake") { return "🥞" }
        if lowercased.contains("waffle") { return "🧇" }

        // Meals
        if lowercased.contains("pizza") { return "🍕" }
        if lowercased.contains("burger") { return "🍔" }
        if lowercased.contains("sandwich") { return "🥪" }
        if lowercased.contains("taco") { return "🌮" }
        if lowercased.contains("burrito") { return "🌯" }
        if lowercased.contains("soup") { return "🍲" }
        if lowercased.contains("sushi") { return "🍣" }
        if lowercased.contains("hot dog") { return "🌭" }
        if lowercased.contains("fries") || lowercased.contains("chips") { return "🍟" }

        // Sweets & Snacks
        if lowercased.contains("cake") { return "🍰" }
        if lowercased.contains("cookie") || lowercased.contains("biscuit") { return "🍪" }
        if lowercased.contains("chocolate") { return "🍫" }
        if lowercased.contains("ice cream") { return "🍦" }
        if lowercased.contains("donut") || lowercased.contains("doughnut") { return "🍩" }
        if lowercased.contains("candy") || lowercased.contains("sweet") { return "🍬" }
        if lowercased.contains("popcorn") { return "🍿" }
        if lowercased.contains("pretzel") { return "🥨" }

        // Drinks
        if lowercased.contains("coffee") { return "☕" }
        if lowercased.contains("tea") { return "🍵" }
        if lowercased.contains("juice") { return "🧃" }
        if lowercased.contains("smoothie") { return "🥤" }
        if lowercased.contains("water") { return "💧" }
        if lowercased.contains("beer") { return "🍺" }
        if lowercased.contains("wine") { return "🍷" }

        // Nuts & Seeds
        if lowercased.contains("nut") || lowercased.contains("almond") || lowercased.contains("peanut") { return "🥜" }

        // Default based on AI or generic
        if isAIGenerated { return "✨" }
        return "🍽️"
    }

    /// Returns an appropriate color for a food name
    /// - Parameters:
    ///   - name: The food name to match
    ///   - isAIGenerated: Whether the entry was AI-generated (affects default)
    /// - Returns: A matching SwiftUI Color
    static func color(for name: String, isAIGenerated: Bool = false) -> Color {
        let lowercased = name.lowercased()

        // Fruits - various colors
        if lowercased.contains("apple") || lowercased.contains("strawberr") || lowercased.contains("cherry") { return .red }
        if lowercased.contains("banana") || lowercased.contains("lemon") || lowercased.contains("mango") { return .yellow }
        if lowercased.contains("orange") || lowercased.contains("peach") || lowercased.contains("carrot") { return .orange }
        if lowercased.contains("grape") || lowercased.contains("blueberr") || lowercased.contains("eggplant") { return .purple }
        if lowercased.contains("avocado") || lowercased.contains("kiwi") || lowercased.contains("broccoli") || lowercased.contains("lettuce") || lowercased.contains("cucumber") { return .green }

        // Proteins
        if lowercased.contains("chicken") || lowercased.contains("beef") || lowercased.contains("fish") || lowercased.contains("egg") { return .brown }

        // Dairy
        if lowercased.contains("milk") || lowercased.contains("cheese") || lowercased.contains("yogurt") { return .blue }

        // Grains
        if lowercased.contains("bread") || lowercased.contains("rice") || lowercased.contains("pasta") { return .brown }

        // Default
        if isAIGenerated { return .purple }
        return .green
    }
}
