import Charts
import SwiftUI

/// Home: Bones + your progress, pick a lift, set up the camera, go.
struct StartView: View {
    let isPro: Bool
    let freeSetAvailable: Bool
    let onStart: (Exercise, ViewMode, CameraSide) -> Void
    let onUpgrade: () -> Void

    @EnvironmentObject private var store: EntitlementStore
    @ObservedObject private var history = HistoryStore.shared
    @AppStorage("home.exercise") private var exerciseRaw = Exercise.squat.rawValue
    @State private var mode: ViewMode = .side
    @State private var cameraSide: CameraSide = .front
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showTrophies = false
    @AppStorage(WorkoutReminder.enabledKey) private var reminderOn = false
    @AppStorage(WorkoutReminder.askedKey) private var reminderAsked = false

    private var exercise: Exercise { Exercise(rawValue: exerciseRaw) ?? .squat }

    var body: some View {
        ZStack {
            GlowBackground(glowAt: UnitPoint(x: 0.85, y: 0.05), intensity: 0.22)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    topBar
                    heroCard
                    if history.records.count >= 2 { progressCard }
                    if !history.records.isEmpty, !reminderOn, !reminderAsked { reminderCard }
                    liftPicker
                    setupCard
                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, 20)
            }
            .safeAreaInset(edge: .bottom) { startBar }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isPro: isPro, onUpgrade: {
                showSettings = false
                onUpgrade()
            })
            .environmentObject(store)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(isPro: isPro, onUpgrade: onUpgrade)
        }
        .sheet(isPresented: $showTrophies) { TrophyView() }
        .onChange(of: exerciseRaw) { if !exercise.supportsFrontView { mode = .side } }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Text("FormCheck")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            if isPro {
                Text("PRO")
                    .font(.caption.weight(.black))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.lime, in: Capsule())
                    .foregroundStyle(.black)
            }
            Spacer()
            iconButton("trophy.fill", "Trophies") { showTrophies = true }
            iconButton("clock.arrow.circlepath", "History") { showHistory = true }
            iconButton("gearshape.fill", "Settings") { showSettings = true }
        }
        .padding(.top, 6)
    }

    private func iconButton(_ name: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Hero

    private var heroCard: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    accessChip.padding(.bottom, 4)
                    Text(greeting)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subGreeting)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 16) {
                    stat("\(setsThisWeek)", "sets this week")
                    stat(bestGrade ?? "–", "best grade")
                    stat("\(dayStreak)", "day streak")
                }
            }
            .padding(.vertical, 18)
            .padding(.leading, 18)
            Spacer(minLength: 0)
            Mascot(pose: history.records.isEmpty ? .wave : .squat, height: 150, animated: true)
                .padding(.trailing, 4)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    @ViewBuilder
    private var accessChip: some View {
        if !isPro {
            Button(action: onUpgrade) {
                Label(freeSetAvailable ? "1 free set today" : "Go Pro",
                      systemImage: freeSetAvailable ? "gift.fill" : "crown.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(freeSetAvailable ? Color.lime.opacity(0.18) : Color.lime))
                    .foregroundStyle(freeSetAvailable ? Color.lime : Color.black)
            }
            .buttonStyle(.plain)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(Color.lime)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var greeting: String {
        if history.records.isEmpty { return "Ready for your\nfirst set?" }
        if let last = history.records.first, Calendar.current.isDateInToday(last.date) { return "Nice work today." }
        return "Let's lift."
    }

    private var subGreeting: String {
        if history.records.isEmpty { return "Bodyweight squats count. Try it right now." }
        if let last = history.records.first { return "Last set: \(last.exercise) · \(last.grade)" }
        return ""
    }

    private var setsThisWeek: Int {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return history.records.filter { $0.date >= start }.count
    }

    private var bestGrade: String? {
        let order = ["A", "B", "C", "D", "F"]
        return history.records.map(\.grade).min { (order.firstIndex(of: $0) ?? 9) < (order.firstIndex(of: $1) ?? 9) }
    }

    private var dayStreak: Int {
        let cal = Calendar.current
        let days = Set(history.records.map { cal.startOfDay(for: $0.date) })
        var day = cal.startOfDay(for: Date())
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while days.contains(day) {
            n += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }

    // MARK: - Progress

    private var recentScores: [(Int, Int)] {
        Array(history.records.prefix(12).reversed().map(\.averageScore).enumerated())
    }

    private var progressCard: some View {
        let unlocked = Achievements.unlocked(in: history.records).count
        let scores = recentScores.map(\.1)
        let delta = (scores.last ?? 0) - (scores.first ?? 0)
        let floor = max(0, (scores.min() ?? 0) - 10)
        return HStack(spacing: 14) {
            Button { showHistory = true } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Form trend").font(.subheadline.weight(.bold))
                        Text((delta >= 0 ? "▲ " : "▼ ") + "\(abs(delta))")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(delta >= 0 ? Color.lime : Color.orange)
                    }
                    Chart(recentScores, id: \.0) { item in
                        AreaMark(x: .value("Set", item.0), yStart: .value("Base", floor), yEnd: .value("Score", item.1))
                            .foregroundStyle(LinearGradient(colors: [Color.lime.opacity(0.35), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Set", item.0), y: .value("Score", item.1))
                            .foregroundStyle(Color.lime)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .interpolationMethod(.monotone)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: floor...100)
                    .frame(height: 46)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .buttonStyle(.plain)

            Button { showTrophies = true } label: {
                VStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(LinearGradient(colors: [.lime, .limeDeep], startPoint: .top, endPoint: .bottom))
                    Text("\(unlocked)/\(Badge.allCases.count)")
                        .font(.system(.headline, design: .rounded).weight(.black))
                    Text("trophies").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(width: 92)
                .padding(.vertical, 14)
                .card()
            }
            .buttonStyle(.plain)
        }
    }

    private var reminderCard: some View {
        HStack(spacing: 12) {
            Mascot(pose: .thumbs, height: 64, animated: false)
            VStack(alignment: .leading, spacing: 6) {
                Text("Want a nudge from Bones?").font(.subheadline.weight(.bold))
                Text("A quick daily reminder at training time keeps your streak alive.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button {
                        Task { reminderOn = await WorkoutReminder.enable(at: WorkoutReminder.minutes) }
                    } label: {
                        Text("Remind me at 6 PM")
                            .font(.caption.weight(.heavy))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.lime, in: Capsule())
                            .foregroundStyle(.black)
                    }
                    Button("Not now") { reminderAsked = true }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .card()
    }

    // MARK: - Lift picker

    private var liftPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose your lift")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Exercise.available) { ex in
                    liftCard(ex)
                }
            }
        }
    }

    private func liftCard(_ ex: Exercise) -> some View {
        let selected = ex == exercise
        return Button {
            withAnimation(.snappy) { exerciseRaw = ex.rawValue }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: ex.symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(selected ? Color.black : Color.lime)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 14).fill(selected ? Color.lime : Color.lime.opacity(0.12)))
                Text(ex.rawValue)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(ex.checks)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .card(highlighted: selected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Camera setup").font(.headline)

            if exercise.supportsFrontView {
                Picker("Camera view", selection: $mode) {
                    ForEach(ViewMode.allCases) { mode in
                        Text("\(mode.rawValue) View").tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Picker("Camera", selection: $cameraSide) {
                ForEach(CameraSide.allCases) { side in
                    Text(side.rawValue).tag(side)
                }
            }
            .pickerStyle(.segmented)

            Text(cameraSide == .front
                 ? "Screen faces you — see the skeleton and cues while you lift."
                 : "Best video quality — coaching is voice-only while you lift.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(setupSteps.enumerated()), id: \.offset) { i, text in
                    SetupStep(number: i + 1, text: text)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var setupSteps: [String] {
        switch (exercise, mode) {
        case (.squat, .side):
            return ["Prop your phone at knee height, side-on",
                    "Stand ~2.5 m (8 ft) away, fully in frame",
                    "Checks depth, forward lean & tempo"]
        case (.squat, .front):
            return ["Prop your phone at knee height, facing you",
                    "Stand ~2.5 m (8 ft) back, fully in frame",
                    "Checks knee tracking & balance — use Side View for depth"]
        case (.deadlift, _):
            return ["Prop your phone at knee height, side-on",
                    "Stand at the bar, ~2.5 m (8 ft) away, fully in frame",
                    "Checks hip timing, bar path & lockout"]
        case (.overheadPress, _):
            return ["Prop your phone at waist height, side-on",
                    "Stand ~2.5 m (8 ft) away, whole body & bar in frame",
                    "Hold the bar at your shoulders to calibrate, then press"]
        case (.lunge, _):
            return ["Prop your phone at knee height, side-on",
                    "Stand ~2.5 m (8 ft) away, fully in frame",
                    "Checks depth & upright torso"]
        case (.bench, _):
            return ["Turn your phone sideways at chest height, side-on to the bench",
                    "Whole bench in frame, ~2.5 m (8 ft) away",
                    "Hold the bar at lockout to calibrate, then press"]
        case (.freestyle, _):
            return ["Prop your phone up, front camera facing you",
                    "Stand back so your whole body is in frame",
                    "Move — records a skeleton clip to share. No scoring."]
        }
    }

    // MARK: - Start

    private var startBar: some View {
        VStack(spacing: 8) {
            Button {
                onStart(exercise, mode, cameraSide)
            } label: {
                Label(startTitle, systemImage: canStart ? "play.fill" : "lock.fill")
            }
            .buttonStyle(LimeButtonStyle())

            if !isPro {
                Text(freeSetAvailable
                     ? "Free plan: 1 scored set per day · Pro: unlimited"
                     : "Next free set tomorrow · Try Pro free for 7 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            LinearGradient(colors: [Color.ink.opacity(0), Color.ink.opacity(0.95), Color.ink],
                           startPoint: .top, endPoint: .bottom)
                .padding(.top, -24)
                .ignoresSafeArea()
        )
    }

    private var canStart: Bool { isPro || freeSetAvailable }

    private var startTitle: String {
        if isPro { return "Start \(exercise.rawValue) Set" }
        return freeSetAvailable ? "Start Free \(exercise.rawValue) Set" : "Unlock Unlimited Sets"
    }
}

private struct SetupStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Color.lime)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.lime.opacity(0.15)))
            Text(text)
                .font(.subheadline)
        }
    }
}

extension Exercise {
    var symbol: String {
        switch self {
        case .squat: return "figure.strengthtraining.traditional"
        case .deadlift: return "figure.strengthtraining.functional"
        case .overheadPress: return "dumbbell.fill"
        case .lunge: return "figure.step.training"
        case .bench: return "figure.strengthtraining.traditional"
        case .freestyle: return "figure.dance"
        }
    }

    var checks: String {
        switch self {
        case .squat: return "Depth, lean, knees, tempo"
        case .deadlift: return "Hip timing, bar path, lockout"
        case .overheadPress: return "Full lockout & lean-back"
        case .lunge: return "Depth & upright torso"
        case .bench: return "Touch, bounce, lockout"
        case .freestyle: return "Skeleton clip, no score"
        }
    }
}

#Preview {
    StartView(isPro: false, freeSetAvailable: true, onStart: { _, _, _ in }, onUpgrade: {})
        .environmentObject(EntitlementStore())
        .preferredColorScheme(.dark)
}
