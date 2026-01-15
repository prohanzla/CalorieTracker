// GlassBackground.swift - Reusable glass effect background modifier
// Made by mpcode

import SwiftUI

/// Reusable glass background effect that adapts to iOS version
/// Uses iOS 26+ glass effect when available, falls back to ultraThinMaterial
struct GlassBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tintColor: Color
    let shadowOpacity: Double

    init(cornerRadius: CGFloat = 20, tintColor: Color = .clear, shadowOpacity: Double = 0.06) {
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.shadowOpacity = shadowOpacity
    }

    func body(content: Content) -> some View {
        content
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.clear)
                        .glassEffect(.regular.tint(tintColor.opacity(0.05)), in: RoundedRectangle(cornerRadius: cornerRadius))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(shadowOpacity), radius: 15, x: 0, y: 8)
                }
            }
    }
}

/// View extension for easy glass background application
extension View {
    /// Applies a glass background effect that adapts to iOS version
    /// - Parameters:
    ///   - cornerRadius: The corner radius of the background (default: 20)
    ///   - tintColor: Optional tint color for the glass effect (default: clear)
    ///   - shadowOpacity: Shadow opacity for fallback material (default: 0.06)
    func glassBackground(
        cornerRadius: CGFloat = 20,
        tintColor: Color = .clear,
        shadowOpacity: Double = 0.06
    ) -> some View {
        modifier(GlassBackgroundModifier(
            cornerRadius: cornerRadius,
            tintColor: tintColor,
            shadowOpacity: shadowOpacity
        ))
    }

    /// Applies a tinted glass background (convenience for coloured glass)
    func tintedGlassBackground(
        _ color: Color,
        cornerRadius: CGFloat = 20
    ) -> some View {
        modifier(GlassBackgroundModifier(
            cornerRadius: cornerRadius,
            tintColor: color,
            shadowOpacity: 0.06
        ))
    }
}
