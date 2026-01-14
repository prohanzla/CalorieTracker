// ImageCropperView.swift - Simple image cropping interface
// Made by mpcode

import SwiftUI
import UIKit

struct ImageCropperView: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    let onCrop: (UIImage) -> Void

    // Crop rectangle state (in screen coordinate space)
    @State private var cropRect: CGRect = .zero

    // Gesture state
    @State private var activeHandle: Handle? = nil
    @State private var dragStartRect: CGRect = .zero

    // Geometry tracking
    @State private var currentGeometrySize: CGSize = .zero
    @State private var isInitialized = false

    private let minCropSize: CGFloat = 80
    private let handleSize: CGFloat = 44

    enum Handle {
        case topLeft, topRight, bottomLeft, bottomRight, center
    }

    // Computed properties for image display
    private func calculateImageFrame(for geometrySize: CGSize) -> CGRect {
        guard geometrySize.width > 0 && geometrySize.height > 0 else {
            return .zero
        }

        let imageAspect = image.size.width / image.size.height
        let viewAspect = geometrySize.width / geometrySize.height

        let displaySize: CGSize
        if imageAspect > viewAspect {
            let width = geometrySize.width
            let height = width / imageAspect
            displaySize = CGSize(width: width, height: height)
        } else {
            let height = geometrySize.height
            let width = height * imageAspect
            displaySize = CGSize(width: width, height: height)
        }

        let origin = CGPoint(
            x: (geometrySize.width - displaySize.width) / 2,
            y: (geometrySize.height - displaySize.height) / 2
        )

        return CGRect(origin: origin, size: displaySize)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let geometrySize = geometry.size
                let imageFrame = calculateImageFrame(for: geometrySize)

                ZStack {
                    Color.black.ignoresSafeArea()

                    // The image centered
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .position(
                            x: geometrySize.width / 2,
                            y: geometrySize.height / 2
                        )

                    // Dark overlay with cutout for crop area
                    CropOverlayView(
                        cropRect: cropRect,
                        containerSize: geometrySize
                    )
                    .allowsHitTesting(false)

                    // Crop rectangle border and handles
                    CropBorderView(cropRect: cropRect)
                        .allowsHitTesting(false)

                    // Gesture detection layer
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleDragChanged(
                                        value: value,
                                        imageBounds: imageFrame
                                    )
                                }
                                .onEnded { _ in
                                    activeHandle = nil
                                }
                        )
                }
                .onChange(of: geometrySize) { oldSize, newSize in
                    if newSize.width > 0 && newSize.height > 0 {
                        currentGeometrySize = newSize
                        if !isInitialized {
                            initializeCropRect(geometrySize: newSize)
                            isInitialized = true
                        }
                    }
                }
                .onAppear {
                    if geometrySize.width > 0 && geometrySize.height > 0 && !isInitialized {
                        currentGeometrySize = geometrySize
                        initializeCropRect(geometrySize: geometrySize)
                        isInitialized = true
                    }
                }
            }
            .navigationTitle("Crop Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let cropped = performCrop()
                        onCrop(cropped)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private func initializeCropRect(geometrySize: CGSize) {
        let imageFrame = calculateImageFrame(for: geometrySize)
        guard imageFrame.width > 0 && imageFrame.height > 0 else { return }

        // Initialize crop to 80% of image, centered
        let margin = min(imageFrame.width, imageFrame.height) * 0.1
        cropRect = CGRect(
            x: imageFrame.origin.x + margin,
            y: imageFrame.origin.y + margin,
            width: imageFrame.width - margin * 2,
            height: imageFrame.height - margin * 2
        )
    }

    // MARK: - Gesture Handling

    private func handleDragChanged(value: DragGesture.Value, imageBounds: CGRect) {
        let location = value.location

        // Determine which handle on first touch
        if activeHandle == nil {
            activeHandle = detectHandle(at: location)
            dragStartRect = cropRect
        }

        guard let handle = activeHandle else { return }

        let delta = CGSize(
            width: value.location.x - value.startLocation.x,
            height: value.location.y - value.startLocation.y
        )

        switch handle {
        case .center:
            moveCrop(delta: delta, bounds: imageBounds)
        default:
            resizeCrop(handle: handle, delta: delta, bounds: imageBounds)
        }
    }

    private func detectHandle(at point: CGPoint) -> Handle? {
        let corners: [(Handle, CGPoint)] = [
            (.topLeft, CGPoint(x: cropRect.minX, y: cropRect.minY)),
            (.topRight, CGPoint(x: cropRect.maxX, y: cropRect.minY)),
            (.bottomLeft, CGPoint(x: cropRect.minX, y: cropRect.maxY)),
            (.bottomRight, CGPoint(x: cropRect.maxX, y: cropRect.maxY))
        ]

        // Check corners first
        for (handle, corner) in corners {
            let distance = hypot(point.x - corner.x, point.y - corner.y)
            if distance < handleSize {
                return handle
            }
        }

        // Check if inside crop rect for center drag
        if cropRect.contains(point) {
            return .center
        }

        return nil
    }

    private func moveCrop(delta: CGSize, bounds: CGRect) {
        var newX = dragStartRect.origin.x + delta.width
        var newY = dragStartRect.origin.y + delta.height

        // Constrain to image bounds
        newX = max(bounds.minX, min(bounds.maxX - cropRect.width, newX))
        newY = max(bounds.minY, min(bounds.maxY - cropRect.height, newY))

        cropRect.origin = CGPoint(x: newX, y: newY)
    }

    private func resizeCrop(handle: Handle, delta: CGSize, bounds: CGRect) {
        var newRect = dragStartRect

        switch handle {
        case .topLeft:
            newRect.origin.x = dragStartRect.origin.x + delta.width
            newRect.origin.y = dragStartRect.origin.y + delta.height
            newRect.size.width = dragStartRect.width - delta.width
            newRect.size.height = dragStartRect.height - delta.height

        case .topRight:
            newRect.origin.y = dragStartRect.origin.y + delta.height
            newRect.size.width = dragStartRect.width + delta.width
            newRect.size.height = dragStartRect.height - delta.height

        case .bottomLeft:
            newRect.origin.x = dragStartRect.origin.x + delta.width
            newRect.size.width = dragStartRect.width - delta.width
            newRect.size.height = dragStartRect.height + delta.height

        case .bottomRight:
            newRect.size.width = dragStartRect.width + delta.width
            newRect.size.height = dragStartRect.height + delta.height

        case .center:
            return
        }

        // Validate minimum size
        guard newRect.width >= minCropSize && newRect.height >= minCropSize else { return }

        // Constrain to image bounds
        newRect.origin.x = max(bounds.minX, newRect.origin.x)
        newRect.origin.y = max(bounds.minY, newRect.origin.y)

        if newRect.maxX > bounds.maxX {
            newRect.size.width = bounds.maxX - newRect.origin.x
        }
        if newRect.maxY > bounds.maxY {
            newRect.size.height = bounds.maxY - newRect.origin.y
        }

        cropRect = newRect
    }

    // MARK: - Perform Crop

    private func performCrop() -> UIImage {
        let imageFrame = calculateImageFrame(for: currentGeometrySize)

        guard imageFrame.width > 0 && imageFrame.height > 0 else {
            return image
        }

        // Convert crop rect from screen coordinates to image coordinates
        let scaleX = image.size.width / imageFrame.width
        let scaleY = image.size.height / imageFrame.height

        // Calculate crop rect relative to image frame
        let relativeX = cropRect.origin.x - imageFrame.origin.x
        let relativeY = cropRect.origin.y - imageFrame.origin.y

        var imageCropRect = CGRect(
            x: relativeX * scaleX,
            y: relativeY * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )

        // Ensure crop rect is within image bounds
        imageCropRect.origin.x = max(0, imageCropRect.origin.x)
        imageCropRect.origin.y = max(0, imageCropRect.origin.y)
        imageCropRect.size.width = min(image.size.width - imageCropRect.origin.x, imageCropRect.size.width)
        imageCropRect.size.height = min(image.size.height - imageCropRect.origin.y, imageCropRect.size.height)

        // Handle image orientation - need to use the properly oriented image
        guard let orientedImage = image.fixedOrientation(),
              let cgImage = orientedImage.cgImage?.cropping(to: imageCropRect) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - UIImage Extension for fixing orientation
extension UIImage {
    func fixedOrientation() -> UIImage? {
        guard imageOrientation != .up else { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage
    }
}

// MARK: - Crop Overlay View (dark overlay with transparent cutout)
struct CropOverlayView: View {
    let cropRect: CGRect
    let containerSize: CGSize

    var body: some View {
        Canvas { context, size in
            // Fill entire canvas with dark overlay
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.6))
            )

            // Cut out the crop area
            context.blendMode = .destinationOut
            context.fill(Path(cropRect), with: .color(.white))
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }
}

// MARK: - Crop Border View (white border, grid lines, corner handles)
struct CropBorderView: View {
    let cropRect: CGRect

    var body: some View {
        ZStack {
            // White border
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)

            // Rule of thirds grid
            Path { path in
                let thirdW = cropRect.width / 3
                let thirdH = cropRect.height / 3

                // Vertical lines
                path.move(to: CGPoint(x: cropRect.minX + thirdW, y: cropRect.minY))
                path.addLine(to: CGPoint(x: cropRect.minX + thirdW, y: cropRect.maxY))
                path.move(to: CGPoint(x: cropRect.minX + thirdW * 2, y: cropRect.minY))
                path.addLine(to: CGPoint(x: cropRect.minX + thirdW * 2, y: cropRect.maxY))

                // Horizontal lines
                path.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + thirdH))
                path.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + thirdH))
                path.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + thirdH * 2))
                path.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + thirdH * 2))
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 1)

            // Corner handles (L-shaped)
            CornerHandleView(position: .topLeft)
                .position(x: cropRect.minX, y: cropRect.minY)

            CornerHandleView(position: .topRight)
                .position(x: cropRect.maxX, y: cropRect.minY)

            CornerHandleView(position: .bottomLeft)
                .position(x: cropRect.minX, y: cropRect.maxY)

            CornerHandleView(position: .bottomRight)
                .position(x: cropRect.maxX, y: cropRect.maxY)
        }
    }
}

// MARK: - Corner Handle View
struct CornerHandleView: View {
    enum Position {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    let position: Position
    private let length: CGFloat = 20
    private let thickness: CGFloat = 4

    var body: some View {
        Canvas { context, size in
            var path = Path()

            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            switch position {
            case .topLeft:
                path.move(to: CGPoint(x: center.x, y: center.y + length))
                path.addLine(to: center)
                path.addLine(to: CGPoint(x: center.x + length, y: center.y))

            case .topRight:
                path.move(to: CGPoint(x: center.x - length, y: center.y))
                path.addLine(to: center)
                path.addLine(to: CGPoint(x: center.x, y: center.y + length))

            case .bottomLeft:
                path.move(to: CGPoint(x: center.x, y: center.y - length))
                path.addLine(to: center)
                path.addLine(to: CGPoint(x: center.x + length, y: center.y))

            case .bottomRight:
                path.move(to: CGPoint(x: center.x - length, y: center.y))
                path.addLine(to: center)
                path.addLine(to: CGPoint(x: center.x, y: center.y - length))
            }

            context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
        }
        .frame(width: 44, height: 44)
    }
}

#Preview {
    ImageCropperView(
        image: UIImage(systemName: "photo.fill")!
    ) { _ in }
}
