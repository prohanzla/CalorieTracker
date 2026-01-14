// NutritionCameraView.swift - Camera view for capturing nutrition labels
// Made by mpcode

import SwiftUI
import AVFoundation
import UIKit

struct NutritionCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var hasPermission = false

    let onCapture: (UIImage) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                if hasPermission {
                    if let image = capturedImage {
                        // Preview captured image
                        VStack(spacing: 20) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding()

                            HStack(spacing: 16) {
                                Button("Retake") {
                                    capturedImage = nil
                                }
                                .buttonStyle(.bordered)

                                Button("Use Photo") {
                                    onCapture(image)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    } else {
                        // Camera view
                        PhotoCaptureView { image in
                            capturedImage = image
                        }
                        .ignoresSafeArea()

                        // Overlay guide
                        VStack {
                            Spacer()

                            VStack(spacing: 8) {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.white)

                                Text("Position nutrition label in view")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                            .padding()
                            .background(.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Spacer()
                            Spacer()
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("Camera Access Required", systemImage: "camera.fill")
                    } description: {
                        Text("Please enable camera access in Settings to scan nutrition labels.")
                    } actions: {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scan Nutrition Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImagePicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                    }
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

// MARK: - Photo Capture View
struct PhotoCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.showsCameraControls = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
        }
    }
}

// MARK: - Image Picker for Photo Library
struct ImagePicker: UIViewControllerRepresentable {
    let onSelect: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onSelect: (UIImage) -> Void

        init(onSelect: @escaping (UIImage) -> Void) {
            self.onSelect = onSelect
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onSelect(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    NutritionCameraView { image in
        print("Captured image")
    }
}
