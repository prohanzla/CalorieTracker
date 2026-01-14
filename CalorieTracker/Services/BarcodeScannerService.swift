// BarcodeScannerService.swift - AVFoundation barcode scanning with close-up support
// Made by mpcode

import AVFoundation
import UIKit

@Observable
class BarcodeScannerService: NSObject {
    var scannedCode: String?
    var isScanning = false
    var error: BarcodeScannerError?

    private var captureSession: AVCaptureSession?

    override init() {
        super.init()
    }

    func checkPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func setupCaptureSession() throws -> AVCaptureSession {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Try to get the best camera for close-up barcode scanning
        let videoCaptureDevice = getBestCameraForBarcodes()

        guard let device = videoCaptureDevice else {
            throw BarcodeScannerError.noCameraAvailable
        }

        // Configure camera for close-up / macro mode
        configureForCloseUp(device: device)

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: device)
        } catch {
            throw BarcodeScannerError.inputError(error)
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            throw BarcodeScannerError.cannotAddInput
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean8,
                .ean13,
                .upce,
                .code128,
                .code39,
                .code93,
                .qr
            ]
        } else {
            throw BarcodeScannerError.cannotAddOutput
        }

        captureSession = session
        return session
    }

    /// Get the best camera device for close-up barcode scanning
    private func getBestCameraForBarcodes() -> AVCaptureDevice? {
        // Try different device types in order of preference for close-up scanning

        // First try the built-in wide angle camera which typically has better close-up
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        }

        // Try dual camera system
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            return device
        }

        // Try dual wide camera
        if let device = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
            return device
        }

        // Fallback to default video device
        return AVCaptureDevice.default(for: .video)
    }

    /// Configure camera for close-up / macro focusing on barcodes
    private func configureForCloseUp(device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()

            // Set focus mode for close-up scanning
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            // Restrict auto-focus to near range (close-up)
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }

            // Enable smooth auto-focus for better tracking of moving barcodes
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }

            // Focus on center of frame where barcode will be
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }

            // Configure exposure for better barcode visibility
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }

            // Try to set minimum focus distance if available (iOS 15+)
            // This helps with very close barcodes
            if #available(iOS 15.0, *) {
                // For devices that support it, try to get the minimum focus distance
                let minDistance = device.minimumFocusDistance
                if minDistance > 0 {
                    // Device reports its minimum focus capability
                    print("Minimum focus distance: \(minDistance)cm")
                }
            }

            // Enable low light boost if available (helps in dim environments)
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }

            device.unlockForConfiguration()
        } catch {
            // Best effort - if we can't configure close-up, continue with default settings
            print("Could not configure camera for close-up: \(error)")
        }
    }

    func startScanning() {
        scannedCode = nil
        error = nil
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    func stopScanning() {
        isScanning = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension BarcodeScannerService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }

        // Haptic feedback on successful scan
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        scannedCode = stringValue
        stopScanning()
    }
}

// MARK: - Errors
enum BarcodeScannerError: LocalizedError {
    case noCameraAvailable
    case inputError(Error)
    case cannotAddInput
    case cannotAddOutput
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noCameraAvailable:
            return "No camera available on this device."
        case .inputError(let error):
            return "Camera input error: \(error.localizedDescription)"
        case .cannotAddInput:
            return "Cannot add camera input to session."
        case .cannotAddOutput:
            return "Cannot add metadata output to session."
        case .permissionDenied:
            return "Camera permission denied. Please enable in Settings."
        }
    }
}
