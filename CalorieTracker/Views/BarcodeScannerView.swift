// BarcodeScannerView.swift - Camera-based barcode scanning view
// Made by mpcode

import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannerService = BarcodeScannerService()
    @State private var hasPermission = false
    @State private var showingPermissionAlert = false

    let onScan: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                if hasPermission {
                    CameraPreviewView(session: try? scannerService.setupCaptureSession())
                        .ignoresSafeArea()

                    // Scanning overlay
                    VStack {
                        Spacer()

                        // Scan frame
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 280, height: 150)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.black.opacity(0.1))
                            )

                        Text("Position barcode within frame")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(.top, 16)

                        Spacer()

                        // Scanned result
                        if let code = scannerService.scannedCode {
                            VStack(spacing: 12) {
                                Text("Scanned: \(code)")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                HStack(spacing: 16) {
                                    Button("Scan Again") {
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
                    ContentUnavailableView {
                        Label("Camera Access Required", systemImage: "camera.fill")
                    } description: {
                        Text("Please enable camera access in Settings to scan barcodes.")
                    } actions: {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if hasPermission {
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
                hasPermission = await scannerService.checkPermission()
                if hasPermission {
                    scannerService.startScanning()
                }
            }
            .onDisappear {
                scannerService.stopScanning()
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

// MARK: - Camera Preview
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.session = session
    }
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            setupPreviewLayer()
        }
    }

    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    private func setupPreviewLayer() {
        previewLayer?.removeFromSuperlayer()

        guard let session = session else { return }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        previewLayer = layer
    }
}

#Preview {
    BarcodeScannerView { code in
        print("Scanned: \(code)")
    }
}
