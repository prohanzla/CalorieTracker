// NutritionCameraView.swift - Camera view for capturing nutrition labels
// Made by mpcode

import SwiftUI
import AVFoundation
import UIKit

struct NutritionCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var hasPermission = false
    @State private var isProcessing = false

    let onCapture: (UIImage) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = capturedImage {
                    // Preview captured image
                    VStack(spacing: 20) {
                        Text("Review Your Photo")
                            .font(.headline)

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 5)

                        Text("Make sure the nutrition label is clearly visible")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            Button {
                                capturedImage = nil
                            } label: {
                                Label("Retake", systemImage: "camera.fill")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                isProcessing = true
                                onCapture(image)
                                dismiss()
                            } label: {
                                if isProcessing {
                                    ProgressView()
                                        .frame(width: 20, height: 20)
                                } else {
                                    Label("Analyse with AI", systemImage: "sparkles")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isProcessing)
                        }
                    }
                    .padding()
                } else {
                    // Camera selection screen
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)

                        Text("Scan Nutrition Label")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Take a photo of the nutrition information on your food packaging")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        Button {
                            showingCamera = true
                        } label: {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Take Photo")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!hasPermission)

                        Button {
                            showingImagePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Choose from Library")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.bordered)

                        if !hasPermission {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Camera access required")
                                    .font(.caption)
                                Button("Settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding()

                    Spacer()
                }
            }
            .navigationTitle("Scan Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCaptureView { image in
                    capturedImage = image
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker { image in
                    capturedImage = image
                }
            }
            .task {
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                switch status {
                case .authorized:
                    hasPermission = true
                case .notDetermined:
                    hasPermission = await AVCaptureDevice.requestAccess(for: .video)
                default:
                    hasPermission = false
                }
            }
        }
    }
}

// MARK: - Camera Capture View (Full Screen)
struct CameraCaptureView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.showsCameraControls = true
        picker.cameraDevice = .rear
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - Image Picker for Photo Library
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onSelect: (UIImage) -> Void
        let dismiss: DismissAction

        init(onSelect: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onSelect = onSelect
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onSelect(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

#Preview {
    NutritionCameraView { image in
        print("Captured image")
    }
}
