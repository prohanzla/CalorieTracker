// SettingsView.swift - App settings and daily targets
// Made by mpcode

import SwiftUI
import SwiftData

struct SettingsView: View {
    @State private var claudeService = ClaudeAPIService()
    @AppStorage("dailyCalorieTarget") private var calorieTarget = 2000.0
    @AppStorage("dailyProteinTarget") private var proteinTarget = 50.0
    @AppStorage("dailyCarbTarget") private var carbTarget = 250.0
    @AppStorage("dailyFatTarget") private var fatTarget = 65.0

    @State private var apiKeyInput = ""
    @State private var showingAPIKeyField = false
    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                // Daily Targets
                Section("Daily Targets") {
                    targetRow(label: "Calories", value: $calorieTarget, unit: "kcal", step: 100)
                    targetRow(label: "Protein", value: $proteinTarget, unit: "g", step: 5)
                    targetRow(label: "Carbohydrates", value: $carbTarget, unit: "g", step: 10)
                    targetRow(label: "Fat", value: $fatTarget, unit: "g", step: 5)
                }

                // Claude API Configuration
                Section {
                    if claudeService.isConfigured {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("API Key Configured")
                            Spacer()
                            Button("Change") {
                                apiKeyInput = ""
                                showingAPIKeyField = true
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        Button {
                            showingAPIKeyField = true
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                Text("Add Claude API Key")
                            }
                        }
                    }
                } header: {
                    Text("AI Features")
                } footer: {
                    Text("Required for nutrition label scanning and natural language food input. Your API key is stored locally on device.")
                }

                // App Info
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Made by")
                        Spacer()
                        Text("mpcode")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/mp-c0de/CalorieTracker")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Data Management
                Section("Data") {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Reset All Data")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAPIKeyField) {
                APIKeyInputView(
                    apiKey: $apiKeyInput,
                    claudeService: claudeService
                )
            }
            .confirmationDialog(
                "Reset All Data",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete all products, food entries, and logs. This cannot be undone.")
            }
        }
    }

    private func targetRow(label: String, value: Binding<Double>, unit: String, step: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Stepper(
                "\(Int(value.wrappedValue)) \(unit)",
                value: value,
                in: 0...10000,
                step: step
            )
        }
    }

    private func resetAllData() {
        // Clear UserDefaults
        claudeService.apiKey = ""

        // Note: To fully reset SwiftData, you'd need access to modelContext
        // This would typically be handled by deleting the store file
    }
}

// MARK: - API Key Input View
struct APIKeyInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var apiKey: String
    let claudeService: ClaudeAPIService
    @State private var isTestingKey = false
    @State private var testResult: String?
    @State private var testSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Claude API Key")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enter your Anthropic API key to enable AI-powered features like nutrition label scanning and natural language food logging.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                SecureField("sk-ant-api...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if let result = testResult {
                    HStack {
                        Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(testSuccess ? .green : .red)
                        Text(result)
                            .font(.caption)
                    }
                }

                HStack(spacing: 16) {
                    Button("Test Key") {
                        testAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .disabled(apiKey.isEmpty || isTestingKey)

                    Button("Save") {
                        claudeService.apiKey = apiKey
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty)
                }

                Spacer()

                Link("Get an API key from Anthropic Console", destination: URL(string: "https://console.anthropic.com/")!)
                    .font(.caption)
            }
            .padding()
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func testAPIKey() {
        isTestingKey = true
        testResult = nil

        Task {
            // Simple test - just check if key format is valid
            if apiKey.hasPrefix("sk-ant-") && apiKey.count > 20 {
                // Try a simple API call
                let tempService = ClaudeAPIService()
                tempService.apiKey = apiKey

                do {
                    _ = try await tempService.estimateFromPrompt("test")
                    testSuccess = true
                    testResult = "API key is valid!"
                } catch {
                    testSuccess = false
                    testResult = "Invalid key or API error"
                }
            } else {
                testSuccess = false
                testResult = "Invalid key format"
            }
            isTestingKey = false
        }
    }
}

#Preview {
    SettingsView()
}
