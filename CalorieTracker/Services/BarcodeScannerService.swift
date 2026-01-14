// BarcodeScannerService.swift - AVFoundation barcode scanning
// Made by mpcode

import AVFoundation
import UIKit

@Observable
class BarcodeScannerService: NSObject {
    var scannedCode: String?
    var isScanning = false
    var error: BarcodeScannerError?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

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

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            throw BarcodeScannerError.noCameraAvailable
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
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

        // Vibrate on successful scan
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

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
