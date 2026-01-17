// BarcodeScannerView.swift - Camera-based barcode scanning view with close-up support
// Made by mpcode

import SwiftUI
import AVFoundation
import UIKit

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannerService = BarcodeScannerService()
    @State private var hasPermission = false
    @State private var captureSession: AVCaptureSession?
    @State private var errorMessage: String?
    @State private var isFlashOn = false

    let onScan: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // DEBUG: View identifier badge
                VStack {
                    HStack {
                        Text("V10")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.red))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 60)
                .padding(.leading, 8)
                .zIndex(100)

                if hasPermission {
                    if let session = captureSession {
                        CameraPreviewView(session: session)
                            .ignoresSafeArea()
                    } else {
                        ProgressView("Starting camera...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                    }

                    // Scanning overlay
                    VStack {
                        Spacer()

                        // Scan frame
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.8), lineWidth: 3)
                                .frame(width: 280, height: 150)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial.opacity(0.2))
                                )

                            // Corner markers
                            VStack {
                                HStack {
                                    CornerMark(rotation: 0)
                                    Spacer()
                                    CornerMark(rotation: 90)
                                }
                                Spacer()
                                HStack {
                                    CornerMark(rotation: 270)
                                    Spacer()
                                    CornerMark(rotation: 180)
                                }
                            }
                            .frame(width: 280, height: 150)
                        }

                        Text("Position barcode within frame")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.top, 16)
                            .shadow(radius: 5)

                        Spacer()

                        // Scanned result
                        if let code = scannerService.scannedCode {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.green)
                                    Text("Barcode Found!")
                                        .font(.headline)
                                }

                                Text(code)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.primary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                HStack(spacing: 16) {
                                    Button {
                                        scannerService.scannedCode = nil
                                        scannerService.startScanning()
                                    } label: {
                                        Label("Scan Again", systemImage: "arrow.clockwise")
                                    }
                                    .buttonStyle(.bordered)

                                    Button {
                                        onScan(code)
                                        dismiss()
                                    } label: {
                                        Label("Use This", systemImage: "checkmark")
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(20)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                            .padding()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(duration: 0.3), value: scannerService.scannedCode)
                } else {
                    VStack(spacing: 24) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text("Camera Access Required")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Please enable camera access in Settings to scan barcodes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Open Settings", systemImage: "gear")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .background(Color.black)
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                if hasPermission && captureSession != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            toggleFlashlight()
                        } label: {
                            Image(systemName: isFlashOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
            .task {
                await setupCamera()
            }
            .onDisappear {
                scannerService.stopScanning()
                turnOffFlashlight()
            }
        }
    }

    private func setupCamera() async {
        hasPermission = await scannerService.checkPermission()

        if hasPermission {
            do {
                let session = try scannerService.setupCaptureSession()
                await MainActor.run {
                    self.captureSession = session
                }
                scannerService.startScanning()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func toggleFlashlight() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            if device.torchMode == .on {
                device.torchMode = .off
                isFlashOn = false
            } else {
                try device.setTorchModeOn(level: 0.8)
                isFlashOn = true
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }

    private func turnOffFlashlight() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch,
              device.torchMode == .on else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }
}

// MARK: - Corner Mark
struct CornerMark: View {
    let rotation: Double

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(Color.green, lineWidth: 4)
        .frame(width: 20, height: 20)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Camera Preview
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.setupSession(session)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    func setupSession(_ session: AVCaptureSession) {
        guard let previewLayer = self.layer as? AVCaptureVideoPreviewLayer else { return }
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        self.previewLayer = previewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

#Preview {
    BarcodeScannerView { code in
        print("Scanned: \(code)")
    }
}
