// AILogView.swift - View for displaying all AI API response logs
// Made by mpcode

import SwiftUI
import SwiftData

struct AILogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AILogEntry.timestamp, order: .reverse) private var logs: [AILogEntry]

    @State private var selectedLog: AILogEntry?
    @State private var showingClearAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                // DEBUG: View identifier badge
                VStack {
                    HStack {
                        Text("V5")
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
                .padding(.top, 50)
                .padding(.leading, 8)

                if logs.isEmpty {
                    ContentUnavailableView {
                        Label("No AI Logs", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("AI responses will appear here after you use AI features")
                    }
                } else {
                    List {
                        ForEach(logs) { log in
                            AILogRow(log: log)
                                .onTapGesture {
                                    selectedLog = log
                                }
                                .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: deleteLogs)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("AI Logs")
            .toolbar {
                if !logs.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingClearAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .sheet(item: $selectedLog) { log in
                AILogDetailView(log: log)
            }
            .alert("Clear All Logs?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllLogs()
                }
            } message: {
                Text("This will permanently delete all AI log entries.")
            }
        }
    }

    private func deleteLogs(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(logs[index])
        }
    }

    private func clearAllLogs() {
        for log in logs {
            modelContext.delete(log)
        }
    }
}

// MARK: - Log Row
struct AILogRow: View {
    let log: AILogEntry

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(log.success ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: log.requestTypeIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(log.success ? .green : .red)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(log.requestTypeDisplayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(log.provider)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(log.input.prefix(60) + (log.input.count > 60 ? "..." : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(log.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Status indicator
            Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(log.success ? .green : .red)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Log Detail View
struct AILogDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let log: AILogEntry

    @State private var showingInputCopied = false
    @State private var showingOutputCopied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        ZStack {
                            Circle()
                                .fill(log.success ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                .frame(width: 50, height: 50)

                            Image(systemName: log.requestTypeIcon)
                                .font(.title2)
                                .foregroundStyle(log.success ? .green : .red)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.requestTypeDisplayName)
                                .font(.title3)
                                .fontWeight(.bold)

                            HStack {
                                Text(log.provider)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text("•")
                                    .foregroundStyle(.secondary)

                                Text(log.formattedDate)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // Status badge
                        Text(log.success ? "Success" : "Failed")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(log.success ? .green : .red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill((log.success ? Color.green : Color.red).opacity(0.15))
                            )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )

                    // Input Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Input")
                                .font(.headline)
                                .fontWeight(.bold)

                            Spacer()

                            Button {
                                UIPasteboard.general.string = log.input
                                showingInputCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    showingInputCopied = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showingInputCopied ? "checkmark" : "doc.on.doc")
                                    Text(showingInputCopied ? "Copied" : "Copy")
                                }
                                .font(.caption)
                                .foregroundStyle(.blue)
                            }
                        }

                        Text(log.input)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }

                    // Output Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Output")
                                .font(.headline)
                                .fontWeight(.bold)

                            Spacer()

                            Button {
                                UIPasteboard.general.string = log.output
                                showingOutputCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    showingOutputCopied = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showingOutputCopied ? "checkmark" : "doc.on.doc")
                                    Text(showingOutputCopied ? "Copied" : "Copy")
                                }
                                .font(.caption)
                                .foregroundStyle(.blue)
                            }
                        }

                        Text(log.output)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(log.success ? .primary : .red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }

                    // Error Section (if failed)
                    if let error = log.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)

                            Text(error)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.red)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Log Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AILogView()
        .modelContainer(for: [Product.self, FoodEntry.self, DailyLog.self, AIFoodTemplate.self, AILogEntry.self], inMemory: true)
}
