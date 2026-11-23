import Charts
import SwiftUI

/// The payoff screen. Animated grade reveal, Bones' reaction, a rep-by-rep
/// chart, a concrete drill for the #1 fault, new trophies, and a story-ready
/// grade card to share.
struct SetSummaryView: View {
    let summary: SetSummary
    let onDone: () -> Void

    @Environment(\.requestReview) private var requestReview
    @ObservedObject private var history = HistoryStore.shared
    @State private var exportingClipID: UUID?
    @State private var shareItem: ShareItem?
    @State private var exportErrorMessage: String?
    @State private var showSavedToast = false
    @State private var shownScore = 0
    @State private var ringProgress: CGFloat = 0
    @State private var gradeShown = false
    @State private var newBadges: [Badge] = []

    private struct ShareItem: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    private var exerciseName: String { summary.reps.first?.exercise.rawValue ?? "Set" }
    private var empty: Bool { summary.clips.isEmpty }
    private var cleanReps: Int { summary.reps.filter(\.faults.isEmpty).count }
    private var bestStreak: Int { summary.clips.map(\.streak).max() ?? 0 }

    /// Previous best average on this lift (history already contains this set
    /// as its newest record when the summary appears).
    private var previousBest: Int? {
        history.records.filter { $0.exercise == exerciseName }.dropFirst().map(\.averageScore).max()
    }
    private var isPersonalBest: Bool {
        guard !empty, let prev = previousBest else { return false }
        return summary.averageScore > prev
    }

    var body: some View {
        ZStack {
            GlowBackground(glowAt: .init(x: 0.5, y: 0.12), intensity: summary.grade == "A" ? 0.4 : 0.26)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    if summary.isFreestyle {
                        freestyleCard
                    } else {
                        reveal
                        if !empty {
                            statsRow
                            if summary.clips.count >= 2 { repChart }
                            fixCard
                            if !newBadges.isEmpty { badgesCard }
                        }
                        repsCard
                    }
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 20)
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $shareItem) { item in ShareSheet(items: item.items) }
        .alert("Export failed",
               isPresented: Binding(get: { exportErrorMessage != nil },
                                    set: { if !$0 { exportErrorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .overlay {
            if summary.grade == "A", !empty, !summary.isFreestyle { ConfettiView() }
        }
        .overlay(alignment: .top) {
            if showSavedToast {
                Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(Color.lime)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: showSavedToast)
        .task { await playReveal() }
        .task {
            guard RatingPrompt.shouldAsk(for: summary) else { return }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            RatingPrompt.markAsked()
            requestReview()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(summary.isFreestyle ? "Nice moves" : "\(exerciseName) · Set complete")
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onDone) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.card))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done")
        }
        .padding(.top, 16)
    }

    // MARK: - Grade reveal

    private var reveal: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(AngularGradient(colors: [.limeDeep, .lime, .lime], center: .center),
                                style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: .lime.opacity(0.5), radius: 12)
                    VStack(spacing: -4) {
                        Text(empty ? "—" : summary.grade)
                            .font(.system(size: 84, weight: .black, design: .rounded))
                            .foregroundStyle(gradeColor)
                            .scaleEffect(gradeShown || empty ? 1 : 0.3)
                            .opacity(gradeShown || empty ? 1 : 0)
                        Text(empty ? "no reps" : "\(shownScore)/100")
                            .font(.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
                .frame(width: 190, height: 190)

                Mascot(pose: empty ? .think : ShareCardView.pose(for: summary.grade), height: 190)
            }
            .padding(.top, 4)

            if isPersonalBest {
                Label("New personal best on \(exerciseName)!", systemImage: "trophy.fill")
                    .font(.subheadline.weight(.heavy))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.lime, in: Capsule())
                    .foregroundStyle(.black)
            }

            SpeechBubble(text: bonesLine)
                .padding(.top, 4)
        }
    }

    private var gradeColor: Color {
        if empty { return .secondary }
        switch summary.grade {
        case "A", "B": return .lime
        case "C": return .yellow
        default: return .orange
        }
    }

    private var bonesLine: String {
        if empty { return "I didn't catch any reps. Check you're fully in frame and try again!" }
        switch summary.grade {
        case "A": return "Textbook. I'm framing that one. 💀🔥"
        case "B": return "Solid set! One fix away from an A."
        case "C": return "Good base. Nail the fix below and watch that grade jump."
        case "D": return "We've got work to do — and I know exactly what."
        default: return "Rough one. Lighten the load and focus on the fix below."
        }
    }

    private func playReveal() async {
        guard !summary.isFreestyle, !empty else { return }
        try? await Task.sleep(nanoseconds: 250_000_000)
        withAnimation(.easeOut(duration: 1.1)) { ringProgress = CGFloat(summary.averageScore) / 100 }
        let target = summary.averageScore
        let steps = 22
        for i in 1...steps {
            try? await Task.sleep(nanoseconds: 45_000_000)
            withAnimation(.snappy(duration: 0.1)) { shownScore = target * i / steps }
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { gradeShown = true }
        UINotificationFeedbackGenerator().notificationOccurred(summary.averageScore >= 80 ? .success : .warning)
        let fresh = Achievements.consumeNew(records: history.records)
        if !fresh.isEmpty {
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.spring) { newBadges = fresh }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            statTile("\(summary.clips.count)", "reps", "number")
            statTile("\(cleanReps)", "clean", "checkmark.seal.fill")
            statTile("\(bestStreak)", "best streak", "flame.fill")
        }
    }

    private func statTile(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundStyle(Color.lime)
            Text(value).font(.system(.title2, design: .rounded).weight(.black))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .card()
    }

    // MARK: - Rep chart

    private var repChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rep by rep").font(.headline)
            Chart(summary.clips) { clip in
                BarMark(x: .value("Rep", "\(clip.score.repIndex)"),
                        y: .value("Score", clip.score.score))
                    .foregroundStyle(clip.score.faults.isEmpty ? Color.lime.gradient : Color.orange.gradient)
                    .cornerRadius(6)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis { AxisMarks(values: [0, 50, 100]) }
            .frame(height: 140)
            HStack(spacing: 14) {
                legend(.lime, "Clean")
                legend(.orange, "Fault")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .card()
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 5) { Circle().fill(c).frame(width: 8, height: 8); Text(t) }
    }

    // MARK: - Fix card

    @ViewBuilder
    private var fixCard: some View {
        if let fault = summary.topFix {
            DrillCard(fault: fault)
        } else {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.title).foregroundStyle(Color.lime)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zero faults. Every rep clean.").font(.headline)
                    Text("Add weight next set — your form can handle it.").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .card(highlighted: true)
        }
    }

    // MARK: - Badges

    private var badgesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(newBadges.count == 1 ? "Trophy unlocked!" : "\(newBadges.count) trophies unlocked!",
                  systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(Color.lime)
            ForEach(newBadges) { badge in
                HStack(spacing: 12) {
                    BadgeIcon(badge: badge, unlocked: true, size: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(badge.title).font(.subheadline.weight(.bold))
                        Text(badge.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(highlighted: true)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: - Reps list

    private var repsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Your reps").font(.headline)
                Spacer()
                if summary.recording != nil, !empty {
                    Text("Tap \(Image(systemName: "play.rectangle.fill")) for a slow-mo replay")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 6)
            if empty {
                Text("No reps detected. Follow the placement guide — whole body in frame, side-on, ~2.5 m away.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(summary.clips) { clip in
                HStack(spacing: 12) {
                    Text("\(clip.score.score)")
                        .font(.system(.headline, design: .rounded).weight(.black).monospacedDigit())
                        .foregroundStyle(clip.score.faults.isEmpty ? Color.black : Color.white)
                        .frame(width: 44, height: 36)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(clip.score.faults.isEmpty ? Color.lime : Color.orange.opacity(0.35)))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Rep \(clip.score.repIndex)").font(.subheadline.weight(.bold))
                            badge(for: clip)
                        }
                        Text(clip.score.faults.isEmpty ? "Clean" : clip.score.faults.map(\.rawValue).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(clip.score.faults.isEmpty ? Color.lime : Color.orange)
                    }
                    Spacer()
                    exportButton(for: clip)
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @ViewBuilder
    private func badge(for clip: RepClip) -> some View {
        if summary.clips.count >= 2 {
            if clip.id == bestClipID { tag("BEST", color: .lime) } else if clip.id == worstClipID { tag("WORST", color: .red) }
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    private var bestClipID: UUID? { summary.clips.max { $0.score.score < $1.score.score }?.id }
    private var worstClipID: UUID? { summary.clips.min { $0.score.score < $1.score.score }?.id }

    @ViewBuilder
    private func exportButton(for clip: RepClip) -> some View {
        if summary.recording != nil, clip.isExportable {
            Menu {
                Button { export(clip, xray: false, save: true) } label: {
                    Label("Save Slow-Mo to Photos", systemImage: "square.and.arrow.down")
                }
                Button { export(clip, xray: false) } label: {
                    Label("Share Replay", systemImage: "square.and.arrow.up")
                }
                Button { export(clip, xray: true) } label: {
                    Label("Share Skeleton Only (anonymous)", systemImage: "figure.stand")
                }
            } label: {
                Group {
                    if exportingClipID == clip.id { ProgressView().tint(.lime) } else {
                        Image(systemName: "play.rectangle.fill").font(.title3).foregroundStyle(Color.lime)
                    }
                }
                .frame(width: 40, height: 36)
            }
            .disabled(exportingClipID != nil)
        }
    }

    // MARK: - Freestyle

    @ViewBuilder
    private var freestyleCard: some View {
        VStack(spacing: 14) {
            Mascot(pose: .win, height: 200)
            if let clip = summary.clips.first, summary.recording != nil {
                Text("Your skeleton clip is ready").font(.title3.weight(.heavy))
                Text("The skeleton is burned in — ready for TikTok.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button { export(clip, xray: false, save: true) } label: {
                    Label(exportingClipID == clip.id ? "Saving…" : "Save to Photos", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(LimeButtonStyle())
                .disabled(exportingClipID != nil)
                Button { export(clip, xray: false) } label: { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(GhostButtonStyle())
                Button { export(clip, xray: true) } label: { Label("Share Skeleton on Black", systemImage: "figure.stand") }
                    .buttonStyle(GhostButtonStyle())
            } else {
                Text("No clip recorded. Try again with your whole body in frame.").foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .card()
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if !summary.isFreestyle, !empty {
                Button(action: shareCard) {
                    Label("Share My Grade Card", systemImage: "square.and.arrow.up.fill")
                }
                .buttonStyle(LimeButtonStyle())
            }
            Button("Done", action: onDone)
                .buttonStyle(GhostButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.ink.opacity(0), Color.ink], startPoint: .top, endPoint: .bottom)
                    .frame(height: 34)
                Color.ink
            }
            .padding(.top, -34)
            .ignoresSafeArea()
        )
    }

    private func shareCard() {
        let card = ShareCardView(exercise: exerciseName, grade: summary.grade, score: summary.averageScore,
                                 reps: summary.clips.count, cleanReps: cleanReps, bestStreak: bestStreak,
                                 personalBest: isPersonalBest)
        guard let image = card.render() else { return }
        #if DEBUG
        try? image.pngData()?.write(to: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sharecard.png"))
        #endif
        shareItem = ShareItem(items: [image, "My \(exerciseName.lowercased()) form just got graded \(summary.grade) by FormCheck 💀 https://apps.apple.com/app/id6790111242"])
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
                    exportingClipID = nil
                    showSavedToast = true
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    showSavedToast = false
                    return
                } else {
                    shareItem = ShareItem(items: [url])
                }
            } catch {
                exportErrorMessage = error.localizedDescription
            }
            exportingClipID = nil
        }
    }
}

/// "Fix this first" card: the fault, why it matters, and Bones' drill.
struct DrillCard: View {
    let fault: FormFault

    var body: some View {
        let drill = fault.drill
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange))
                VStack(alignment: .leading, spacing: 1) {
                    Text("FIX THIS FIRST").font(.caption2.weight(.black)).foregroundStyle(.orange)
                    Text(fault.rawValue).font(.headline)
                }
                Spacer()
            }
            Text(drill.why).font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(Color.white.opacity(0.1))
            Text("Bones' drill: \(drill.title)").font(.subheadline.weight(.bold)).foregroundStyle(Color.lime)
            ForEach(Array(drill.steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)")
                        .font(.caption.weight(.heavy)).foregroundStyle(Color.lime)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.lime.opacity(0.15)))
                    Text(step).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Next set, listen for: “\(fault.cue)”")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// Round trophy medallion; greyed-out with a lock when not yet earned.
struct BadgeIcon: View {
    let badge: Badge
    let unlocked: Bool
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(unlocked
                      ? AnyShapeStyle(LinearGradient(colors: [.lime, .limeDeep], startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(Color.white.opacity(0.06)))
            Circle().strokeBorder(unlocked ? Color.white.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 2)
            Image(systemName: unlocked ? badge.symbol : "lock.fill")
                .font(.system(size: size * (unlocked ? 0.42 : 0.32), weight: .bold))
                .foregroundStyle(unlocked ? Color.black : Color.white.opacity(0.3))
        }
        .frame(width: size, height: size)
        .shadow(color: unlocked ? .lime.opacity(0.4) : .clear, radius: 10)
    }
}

#Preview {
    SetSummaryView(summary: SetSummary(clips: [], recording: nil)) {}
}
