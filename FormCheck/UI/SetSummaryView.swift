import SwiftUI

struct SetSummaryView: View {
    let summary: SetSummary
    let onDone: () -> Void

    @State private var exportingClipID: UUID?
    @State private var shareItem: ShareItem?
    @State private var exportErrorMessage: String?
    @State private var showSavedToast = false

    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        NavigationStack {
            List {
                gradeSection
                repsSection
            }
            .navigationTitle("Set Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
            .alert("Export failed",
                   isPresented: Binding(
                       get: { exportErrorMessage != nil },
                       set: { if !$0 { exportErrorMessage = nil } }
                   )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "")
            }
            .overlay {
                if summary.grade == "A", !summary.clips.isEmpty {
                    ConfettiView()
                }
            }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.green)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: showSavedToast)
        }
    }

    private var gradeSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Grade")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    // No reps ≠ an F — show a neutral dash instead of failing
                    // someone for an empty set.
                    Text(summary.clips.isEmpty ? "—" : summary.grade)
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(summary.clips.isEmpty ? Color.secondary
                                         : summary.averageScore >= 80 ? Color.green : Color.orange)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(summary.clips.count) reps")
                        .font(.headline)
                    Text("Avg score \(summary.averageScore)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)

            if let fix = summary.topFix {
                Label {
                    Text("Fix this first: **\(fix.rawValue)**")
                } icon: {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(.orange)
                }
            }

            if summary.recording != nil, !summary.clips.isEmpty {
                Label {
                    Text("Tap \(Image(systemName: "square.and.arrow.up")) to export a slow-mo replay with the skeleton burned in.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "film.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var repsSection: some View {
        Section("Reps") {
            if summary.clips.isEmpty {
                Text("No reps detected. Check the camera placement guide and try again.")
                    .foregroundStyle(.secondary)
            }
            ForEach(summary.clips) { clip in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Rep \(clip.score.repIndex)")
                                .font(.headline)
                            badge(for: clip)
                        }
                        if clip.score.faults.isEmpty {
                            Text("Clean")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text(clip.score.faults.map(\.rawValue).joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Text("\(clip.score.score)")
                        .font(.headline.monospacedDigit())
                    exportButton(for: clip)
                }
            }
        }
    }

    @ViewBuilder
    private func badge(for clip: RepClip) -> some View {
        if summary.clips.count >= 2 {
            if clip.id == bestClipID {
                tag("BEST", color: .green)
            } else if clip.id == worstClipID {
                tag("WORST", color: .red)
            }
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    private var bestClipID: UUID? {
        summary.clips.max { $0.score.score < $1.score.score }?.id
    }

    private var worstClipID: UUID? {
        summary.clips.min { $0.score.score < $1.score.score }?.id
    }

    @ViewBuilder
    private func exportButton(for clip: RepClip) -> some View {
        if summary.recording != nil, clip.isExportable {
            Menu {
                Button {
                    export(clip, xray: false, save: true)
                } label: {
                    Label("Save to Photos", systemImage: "square.and.arrow.down")
                }
                Button {
                    export(clip, xray: false)
                } label: {
                    Label("Share Replay", systemImage: "square.and.arrow.up")
                }
                Button {
                    export(clip, xray: true)
                } label: {
                    Label("Share Skeleton Only (anonymous)", systemImage: "figure.stand")
                }
            } label: {
                if exportingClipID == clip.id {
                    ProgressView()
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.green)
                }
            }
            .buttonStyle(.borderless)
            .disabled(exportingClipID != nil)
        }
    }

    /// `save: true` writes straight to Photos; otherwise opens the share sheet.
    private func export(_ clip: RepClip, xray: Bool, save: Bool = false) {
        guard let recording = summary.recording else { return }
        exportingClipID = clip.id
        Task {
            do {
                let url = try await ReplayExporter.export(recording: recording, clip: clip, xray: xray)
                if save {
                    try await PhotoSaver.saveVideo(at: url)
                    // Clear the spinner as soon as the save completes; the
                    // toast then times out on its own so buttons re-enable
                    // immediately instead of after the toast.
                    exportingClipID = nil
                    showSavedToast = true
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    showSavedToast = false
                    return
                } else {
                    shareItem = ShareItem(url: url)
                }
            } catch {
                exportErrorMessage = error.localizedDescription
            }
            exportingClipID = nil
        }
    }
}

#Preview {
    SetSummaryView(summary: SetSummary(clips: [], recording: nil)) {}
}
