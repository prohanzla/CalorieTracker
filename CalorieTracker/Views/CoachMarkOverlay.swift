// CoachMarkOverlay.swift - Tutorial tooltip overlay component
// Made by mpcode

import SwiftUI

struct CoachMarkOverlay: View {
    let coachMark: CoachMark
    let currentStep: Int
    let totalSteps: Int
    let tabBarHeight: CGFloat
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var tooltipSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark overlay background
                Color.black.opacity(0.75)
                    .ignoresSafeArea()

                // Cutout for highlighted tab (if applicable)
                if let tabIndex = coachMark.tabIndex {
                    tabHighlight(for: tabIndex, in: geometry)
                }

                // Tooltip bubble
                tooltipBubble
                    .position(tooltipPosition(in: geometry))
            }
        }
        .transition(.opacity)
    }

    // MARK: - Tab Highlight
    @ViewBuilder
    private func tabHighlight(for tabIndex: Int, in geometry: GeometryProxy) -> some View {
        // Calculate tab position more precisely
        let tabWidth = geometry.size.width / 5
        let tabX = tabWidth * CGFloat(tabIndex) + tabWidth / 2
        // Position the highlight at the tab icon center
        // Tab icons are in the middle of the tab bar, which sits just above the safe area
        let safeAreaBottom = geometry.safeAreaInsets.bottom
        // Position at the center of tab bar icons - adjusted lower to align with actual icon positions
        let tabIconY = geometry.size.height - safeAreaBottom - 9

        // Spotlight effect on the tab
        Circle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 65, height: 65)
            .position(x: tabX, y: tabIconY)

        // Pulsing ring
        Circle()
            .stroke(Color.white.opacity(0.6), lineWidth: 2)
            .frame(width: 75, height: 75)
            .position(x: tabX, y: tabIconY)
    }

    // MARK: - Tooltip Bubble
    private var tooltipBubble: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Step indicator
            HStack {
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Skip") {
                    onSkip()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Title
            Text(coachMark.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            // Message
            Text(coachMark.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: geo.size.width * (Double(currentStep) / Double(totalSteps)), height: 4)
                }
            }
            .frame(height: 4)

            // Navigation buttons
            HStack {
                if currentStep > 1 {
                    Button {
                        // Previous handled by parent if needed
                    } label: {
                        Text("Back")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    onNext()
                } label: {
                    Text(currentStep == totalSteps ? "Done" : "Next")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .overlay(
            // Arrow pointing to target
            arrowView
        )
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    tooltipSize = geo.size
                }
            }
        )
    }

    // MARK: - Arrow
    @ViewBuilder
    private var arrowView: some View {
        if coachMark.position == .above {
            Triangle()
                .fill(Color(.systemBackground))
                .frame(width: 20, height: 12)
                .rotationEffect(.degrees(180))
                .offset(y: tooltipSize.height / 2 + 6)
        } else {
            Triangle()
                .fill(Color(.systemBackground))
                .frame(width: 20, height: 12)
                .offset(y: -tooltipSize.height / 2 - 6)
        }
    }

    // MARK: - Tooltip Position
    private func tooltipPosition(in geometry: GeometryProxy) -> CGPoint {
        let centerX = geometry.size.width / 2
        let safeAreaBottom = geometry.safeAreaInsets.bottom

        if let tabIndex = coachMark.tabIndex {
            // Position relative to tab
            let tabWidth = geometry.size.width / 5
            _ = tabWidth * CGFloat(tabIndex) + tabWidth / 2  // tabX for reference
            let tabIconY = geometry.size.height - safeAreaBottom - 30

            switch coachMark.position {
            case .above:
                // Position tooltip above the tab, centered horizontally but clamped to screen edges
                let clampedX = min(max(centerX, 170), geometry.size.width - 170)
                return CGPoint(x: clampedX, y: tabIconY - 160)
            case .below:
                return CGPoint(x: centerX, y: geometry.size.height / 2)
            default:
                return CGPoint(x: centerX, y: geometry.size.height / 2)
            }
        }

        // Default center position
        return CGPoint(x: centerX, y: geometry.size.height / 2)
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    CoachMarkOverlay(
        coachMark: CoachMark(
            id: "test",
            title: "Add Food",
            message: "Tap here to log your meals. You can use AI, scan barcodes, or add food manually.",
            tabIndex: 1,
            position: .above
        ),
        currentStep: 2,
        totalSteps: 5,
        tabBarHeight: 83,
        onNext: {},
        onSkip: {}
    )
}
