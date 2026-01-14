// AppBackground.swift - Dynamic animated background for the app
// Made by mpcode

import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateGradient = false

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: colorScheme == .dark ? darkColors : lightColors,
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()

            // Floating orbs for depth
            GeometryReader { geometry in
                // Top right orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accentColor.opacity(0.3), accentColor.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(
                        x: geometry.size.width * 0.5 + (animateGradient ? 20 : -20),
                        y: -50 + (animateGradient ? 30 : -30)
                    )

                // Bottom left orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [secondaryAccentColor.opacity(0.25), secondaryAccentColor.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 250, height: 250)
                    .offset(
                        x: -80 + (animateGradient ? -15 : 15),
                        y: geometry.size.height * 0.6 + (animateGradient ? -20 : 20)
                    )

                // Center accent orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [tertiaryAccentColor.opacity(0.15), tertiaryAccentColor.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(
                        x: geometry.size.width * 0.3 + (animateGradient ? 10 : -10),
                        y: geometry.size.height * 0.4 + (animateGradient ? 15 : -15)
                    )
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 8)
                .repeatForever(autoreverses: true)
            ) {
                animateGradient = true
            }
        }
    }

    // MARK: - Colors
    private var lightColors: [Color] {
        [
            Color(red: 0.98, green: 0.98, blue: 1.0),
            Color(red: 0.95, green: 0.97, blue: 1.0),
            Color(red: 0.92, green: 0.96, blue: 0.98)
        ]
    }

    private var darkColors: [Color] {
        [
            Color(red: 0.08, green: 0.08, blue: 0.12),
            Color(red: 0.06, green: 0.08, blue: 0.14),
            Color(red: 0.04, green: 0.06, blue: 0.10)
        ]
    }

    private var accentColor: Color {
        colorScheme == .dark ? .green : .green
    }

    private var secondaryAccentColor: Color {
        colorScheme == .dark ? .blue : .blue
    }

    private var tertiaryAccentColor: Color {
        colorScheme == .dark ? .purple : .orange
    }
}

// View modifier for easy application
extension View {
    func appBackground() -> some View {
        self.background {
            AppBackground()
        }
    }
}

#Preview {
    AppBackground()
}
