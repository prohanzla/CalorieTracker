// BarcodeScannerView.swift - Camera-based barcode scanning view
// Made by mpcode

import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannerService = BarcodeScannerService()
    @State private var hasPermission = false
    @State private var captureSession: AVCaptureSession?
    @State private var errorMessage: String?

    let onScan: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
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
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 280, height: 150)

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
                            .foregroundStyle(.white)
                            .padding(.top, 16)
                            .shadow(radius: 2)

                        Spacer()

                        // Scanned result
                        if let code = scannerService.scannedCode {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Barcode Found!")
                                        .font(.headline)
                                }

                                Text(code)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal)

                                HStack(spacing: 16) {
                                    Button("Scan Again") {
                                        scannerService.scannedCode = nil
                                        scannerService.startScanning()
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Use This") {
                                        onScan(code)
                                        dismiss()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding()
                        }
                    }
                } else {
                    VStack(spacing: 20) {
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
                            .padding(.horizontal)

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding()
                        }

                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .background(Color.black)
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if hasPermission && captureSession != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            toggleFlashlight()
                        } label: {
                            Image(systemName: "flashlight.on.fill")
                        }
                    }
                }
            }
            .task {
                await setupCamera()
            }
            .onDisappear {
                scannerService.stopScanning()
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

        try? device.lockForConfiguration()
        device.torchMode = device.torchMode == .on ? .off : .on
        device.unlockForConfiguration()
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

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Session already set up
    }
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
