import SwiftUI

struct StartView: View {
    let onStart: (Exercise, ViewMode, CameraSide) -> Void

    @State private var exercise: Exercise = .squat
    @State private var mode: ViewMode = .side
    @State private var cameraSide: CameraSide = .front
    @State private var showSettings = false
    @State private var showHistory = false

    var body: some View {
        // Scrolls so landscape (short) screens don't clip the setup card.
        ScrollView(showsIndicators: false) {
            content
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 10) {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 20)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                onStart(exercise, mode, cameraSide)
            } label: {
                Text("Start \(exercise.rawValue) Set")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private var content: some View {
        VStack(spacing: 28) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("FormCheck")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                Text("Real-time squat coaching.\nAll on-device — nothing leaves your phone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Picker("Exercise", selection: $exercise) {
                    ForEach(Exercise.available) { exercise in
                        Text(exercise.rawValue).tag(exercise)
                    }
                }
                .pickerStyle(.segmented)

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
                     ? "Screen faces you — live feedback visible while you lift"
                     : "Best video quality — coaching is voice-only while you lift")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    switch (exercise, mode) {
                    case (.squat, .side):
                        SetupStep(number: 1, text: "Prop your phone at knee height, side-on")
                        SetupStep(number: 2, text: "Stand ~2.5 m (8 ft) away, fully in frame")
                        SetupStep(number: 3, text: "Checks depth, forward lean & tempo")
                    case (.squat, .front):
                        SetupStep(number: 1, text: "Prop your phone at knee height, facing you")
                        SetupStep(number: 2, text: "Stand ~2.5 m (8 ft) back, fully in frame")
                        SetupStep(number: 3, text: "Checks knee tracking & balance — use Side View for depth")
                    case (.deadlift, _):
                        SetupStep(number: 1, text: "Prop your phone at knee height, side-on")
                        SetupStep(number: 2, text: "Stand at the bar, ~2.5 m (8 ft) away, fully in frame")
                        SetupStep(number: 3, text: "Checks hip timing, bar path & lockout")
                    case (.bench, _):
                        SetupStep(number: 1, text: "Turn your phone sideways (landscape) at chest height, side-on to the bench")
                        SetupStep(number: 2, text: "Whole bench in frame, ~2.5 m (8 ft) away")
                        SetupStep(number: 3, text: "Hold the bar at lockout to calibrate, then press")
                    case (.freestyle, _):
                        SetupStep(number: 1, text: "Prop your phone up, front camera facing you")
                        SetupStep(number: 2, text: "Stand back so your whole body is in frame")
                        SetupStep(number: 3, text: "Dance or move — records a skeleton clip to share. No scoring.")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .onChange(of: exercise) {
                if !exercise.supportsFrontView { mode = .side }
            }
        }
        .padding(24)
    }
}

private struct SetupStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.green.opacity(0.25)))
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    StartView { _, _, _ in }
        .preferredColorScheme(.dark)
}
