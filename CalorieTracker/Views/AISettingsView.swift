// AISettingsView.swift - AI provider selection and configuration
// Made by mpcode

import SwiftUI

struct AISettingsView: View {
    @State private var aiManager = AIServiceManager.shared
    @State private var selectedProviderForKey: AIProvider?

    var body: some View {
        List {
            // Provider Selection
            Section {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    ProviderRow(
                        provider: provider,
                        isSelected: aiManager.selectedProvider == provider,
                        isConfigured: aiManager.isConfigured(provider: provider),
                        onSelect: {
                            aiManager.selectedProvider = provider
                        },
                        onConfigureTap: {
                            selectedProviderForKey = provider
                        }
                    )
                }
            } header: {
                Text("AI Provider")
            } footer: {
                Text("Select which AI service to use. Note: Gemini free tier has strict rate limits on image processing - use Claude or ChatGPT for nutrition label scanning.")
            }

            // Current Status
            Section("Status") {
                HStack {
                    Text("Active Provider")
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: aiManager.selectedProvider.iconName)
                        Text(aiManager.selectedProvider.displayName)
                    }
                    .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    if aiManager.isConfigured {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Ready")
                                .foregroundStyle(.green)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("API Key Required")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            // Info Section
            Section("About AI Providers") {
                VStack(alignment: .leading, spacing: 12) {
                    ProviderInfoRow(
                        icon: "brain.head.profile",
                        name: "Claude",
                        description: "Anthropic's AI. Excellent accuracy, pay-per-use."
                    )

                    ProviderInfoRow(
                        icon: "sparkles",
                        name: "Gemini",
                        description: "Google's AI. Free tier for text queries, limited image support."
                    )

                    ProviderInfoRow(
                        icon: "bubble.left.and.bubble.right",
                        name: "ChatGPT",
                        description: "OpenAI's AI. Most popular, pay-per-use."
                    )
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("AI Settings")
        .sheet(item: $selectedProviderForKey) { provider in
            APIKeyInputSheet(provider: provider)
        }
    }
}

// MARK: - Provider Row
struct ProviderRow: View {
    let provider: AIProvider
    let isSelected: Bool
    let isConfigured: Bool
    let onSelect: () -> Void
    let onConfigureTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Button {
                onSelect()
            } label: {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .buttonStyle(.plain)

            // Provider info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: provider.iconName)
                        .foregroundStyle(.blue)
                    Text(provider.displayName)
                        .fontWeight(.medium)

                    if provider == .gemini {
                        Text("Free")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }

                Text(provider.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Configuration status
            Button {
                onConfigureTap()
            } label: {
                if isConfigured {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Add Key")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isConfigured {
                onSelect()
            } else {
                onConfigureTap()
            }
        }
    }
}

// MARK: - Provider Info Row
struct ProviderInfoRow: View {
    let icon: String
    let name: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - API Key Input Sheet
struct APIKeyInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    let provider: AIProvider

    @State private var apiKey = ""
    @State private var isTestingKey = false
    @State private var testResult: String?
    @State private var testSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Provider icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: provider.iconName)
                        .font(.system(size: 36))
                        .foregroundStyle(.blue)
                }

                // Title
                VStack(spacing: 8) {
                    Text("\(provider.displayName) API Key")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter your \(provider.displayName) API key to enable AI-powered nutrition scanning.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // API Key field
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SecureField(keyPlaceholder, text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .fontDesign(.monospaced)
                }

                // Test result
                if let result = testResult {
                    HStack {
                        Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(testSuccess ? .green : .red)
                        Text(result)
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(testSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Buttons
                HStack(spacing: 16) {
                    Button {
                        testAPIKey()
                    } label: {
                        if isTestingKey {
                            ProgressView()
                                .frame(width: 20, height: 20)
                        } else {
                            Text("Test Key")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(apiKey.isEmpty || isTestingKey)

                    Button("Save") {
                        AIServiceManager.shared.setAPIKey(apiKey, for: provider)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty)
                }

                Spacer()

                // Get API key link
                Link(destination: provider.consoleURL) {
                    HStack {
                        Text("Get an API key from \(provider.displayName)")
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.caption)
                }

                // Remove key button (if configured)
                if !AIServiceManager.shared.getAPIKey(for: provider).isEmpty {
                    Button(role: .destructive) {
                        AIServiceManager.shared.setAPIKey("", for: provider)
                        apiKey = ""
                        testResult = nil
                    } label: {
                        Label("Remove API Key", systemImage: "trash")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .navigationTitle("Configure \(provider.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                apiKey = AIServiceManager.shared.getAPIKey(for: provider)
            }
        }
    }

    private var keyPlaceholder: String {
        switch provider {
        case .claude: return "sk-ant-api..."
        case .gemini: return "AIza..."
        case .openAI: return "sk-..."
        }
    }

    private func testAPIKey() {
        isTestingKey = true
        testResult = nil

        Task {
            do {
                // Create temporary service with the key
                let tempManager = AIServiceManager.shared
                let originalKey = tempManager.getAPIKey(for: provider)

                // Temporarily set the key
                tempManager.setAPIKey(apiKey, for: provider)
                let service = tempManager.service(for: provider)

                // Try a simple estimation
                _ = try await service.estimateFromPrompt("test apple")

                testSuccess = true
                testResult = "API key is valid!"

                // Restore original if different
                if originalKey != apiKey {
                    tempManager.setAPIKey(originalKey, for: provider)
                }
            } catch {
                testSuccess = false
                if let aiError = error as? AIServiceError {
                    testResult = aiError.localizedDescription
                } else {
                    testResult = "Invalid key or API error"
                }
            }
            isTestingKey = false
        }
    }
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
}
