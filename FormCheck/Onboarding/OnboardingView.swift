import SwiftUI

/// Bones intro → how it works → 4-question quiz → "building profile" →
/// tailored plan. Ends by calling `onComplete`; ContentView then shows the
/// (dismissible) paywall.
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var stepIndex = 0
    @AppStorage("quiz.load") private var loadAnswer = ""
    @AppStorage("quiz.goal") private var goalAnswer = ""
    @AppStorage("quiz.pain") private var painAnswer = ""
    @AppStorage("quiz.place") private var placeAnswer = ""

    private var quizCount: Int { OnboardingQuiz.questions.count }
    private let firstQuiz = 2

    var body: some View {
        ZStack {
            GlowBackground(glowAt: UnitPoint(x: 0.5, y: 0.25), intensity: stepIndex == 0 ? 0.38 : 0.22)
                .animation(.easeInOut, value: stepIndex)

            VStack(spacing: 0) {
                if (firstQuiz..<(firstQuiz + quizCount)).contains(stepIndex) {
                    progressBar
                }

                Group {
                    switch stepIndex {
                    case 0:
                        WelcomeScreen { advance() }
                    case 1:
                        HowItWorksScreen { advance() }
                    case firstQuiz..<(firstQuiz + quizCount):
                        let question = OnboardingQuiz.questions[stepIndex - firstQuiz]
                        QuizScreen(question: question) { answer in
                            record(answer, for: question.id)
                            advance()
                        }
                        .id(question.id)
                    case firstQuiz + quizCount:
                        AnalyzingScreen { advance() }
                    default:
                        PlanScreen(lines: OnboardingQuiz.profileLines(goal: goalAnswer, pain: painAnswer, place: placeAnswer)) {
                            onComplete()
                        }
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .preferredColorScheme(.dark)
        .animation(.snappy, value: stepIndex)
    }

    private var progressBar: some View {
        HStack(spacing: 12) {
            Button {
                stepIndex -= 1
            } label: {
                Image(systemName: "chevron.left").font(.headline).foregroundStyle(.white.opacity(0.6))
            }
            .opacity(stepIndex > firstQuiz ? 1 : 0)
            .disabled(stepIndex <= firstQuiz)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(Color.lime)
                        .frame(width: geo.size.width * Double(stepIndex - firstQuiz + 1) / Double(quizCount))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        stepIndex += 1
    }

    private func record(_ answer: String, for questionID: String) {
        switch questionID {
        case "load": loadAnswer = answer
        case "goal": goalAnswer = answer
        case "pain": painAnswer = answer
        case "place": placeAnswer = answer
        default: break
        }
    }
}

// MARK: - Welcome

private struct WelcomeScreen: View {
    let onContinue: () -> Void
    @State private var show = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)
            ZStack(alignment: .top) {
                Mascot(pose: .wave, height: 330)
                    .padding(.top, 44)
                SpeechBubble(text: "Hey! I'm Bones 👋")
                    .offset(x: 70)
                    .scaleEffect(show ? 1 : 0.4, anchor: .bottomLeading)
                    .opacity(show ? 1 : 0)
            }
            VStack(spacing: 10) {
                Text("Your AI form coach\nlives in your phone.")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text("Prop it up, lift, and I'll watch every rep — calling out what to fix, live.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            Spacer()
            Button("Let's Go", action: onContinue)
                .buttonStyle(LimeButtonStyle())
            Label("No account · Video never leaves your phone", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.5)) { show = true }
        }
    }
}

// MARK: - How it works

private struct HowItWorksScreen: View {
    let onContinue: () -> Void
    @State private var visible = 0

    private let steps: [(String, String, String)] = [
        ("iphone.gen3", "Prop up your phone", "Knee height, side-on, about 2.5 m away. Any gym, any garage."),
        ("figure.strengthtraining.traditional", "Lift like normal", "A live skeleton tracks your joints in real time."),
        ("speaker.wave.3.fill", "Hear what to fix", "“Go deeper.” “Chest up.” “Knees out.” Every rep scored A–F."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 10)
            HStack(alignment: .bottom) {
                Text("Here's how\nit works")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Mascot(pose: .squat, height: 150)
            }
            VStack(spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).fill(Color.lime.opacity(0.14))
                            Image(systemName: s.0).font(.title3.weight(.bold)).foregroundStyle(Color.lime)
                        }
                        .frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(i + 1). \(s.1)").font(.headline).foregroundStyle(.white)
                            Text(s.2).font(.subheadline).foregroundStyle(.white.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .card()
                    .opacity(visible > i ? 1 : 0)
                    .offset(y: visible > i ? 0 : 16)
                }
            }
            Spacer()
            Button("Build My Coaching Plan", action: onContinue)
                .buttonStyle(LimeButtonStyle())
        }
        .padding(24)
        .task {
            for i in 1...steps.count {
                try? await Task.sleep(nanoseconds: 220_000_000)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { visible = i }
            }
        }
    }
}

// MARK: - Quiz

private struct QuizScreen: View {
    let question: QuizQuestion
    let onAnswer: (String) -> Void

    @State private var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(question.title)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(question.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 28)

            VStack(spacing: 12) {
                ForEach(question.options) { option in
                    Button {
                        guard selected == nil else { return }
                        selected = option.id
                        UISelectionFeedbackGenerator().selectionChanged()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onAnswer(option.label)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Text(option.emoji)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                            Text(option.label)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: selected == option.id ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected == option.id ? Color.lime : Color.white.opacity(0.2))
                        }
                        .padding(14)
                        .card(highlighted: selected == option.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Analyzing

private struct AnalyzingScreen: View {
    let onFinished: () -> Void

    private let items = [
        "Calibrating depth thresholds",
        "Setting lean & knee-tracking alerts",
        "Tuning voice cues to your level",
        "Preparing your coaching plan",
    ]
    @State private var visibleCount = 0
    @State private var progress = 0.0

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Mascot(pose: .think, height: 230)
            Text("Building your coaching plan…")
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
            ProgressView(value: progress)
                .tint(.lime)
                .padding(.horizontal, 40)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 10) {
                        Image(systemName: index < visibleCount ? "checkmark.circle.fill" : "circle.dotted")
                            .foregroundStyle(index < visibleCount ? Color.lime : Color.white.opacity(0.3))
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(index < visibleCount ? Color.white : Color.white.opacity(0.4))
                    }
                }
            }
            Spacer()
            Spacer()
        }
        .padding(24)
        .task {
            for step in 1...items.count {
                withAnimation(.linear(duration: 0.65)) { progress = Double(step) / Double(items.count) }
                try? await Task.sleep(nanoseconds: 650_000_000)
                withAnimation(.snappy) { visibleCount = step }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            onFinished()
        }
    }
}

// MARK: - Plan

private struct PlanScreen: View {
    let lines: [String]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your plan\nis ready.")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Here's what I'll watch for, every rep:")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                Mascot(pose: .thumbs, height: 170)
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 15) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.lime)
                        Text(line)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            Spacer()

            Button("Continue", action: onContinue)
                .buttonStyle(LimeButtonStyle())
            Label("100% on-device. Your video never leaves your phone.", systemImage: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(24)
    }
}

#Preview {
    OnboardingView {}
}
