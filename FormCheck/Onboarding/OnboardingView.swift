import SwiftUI

/// Welcome → 3-question quiz → "building profile" moment → tailored plan.
/// Ends by calling `onComplete`; ContentView then gates on the paywall.
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var stepIndex = 0
    @AppStorage("quiz.load") private var loadAnswer = ""
    @AppStorage("quiz.goal") private var goalAnswer = ""
    @AppStorage("quiz.pain") private var painAnswer = ""

    private var quizCount: Int { OnboardingQuiz.questions.count }

    var body: some View {
        VStack(spacing: 0) {
            if (1...quizCount).contains(stepIndex) {
                ProgressView(value: Double(stepIndex), total: Double(quizCount))
                    .tint(.green)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }

            Group {
                switch stepIndex {
                case 0:
                    WelcomeScreen { advance() }
                case 1...quizCount:
                    let question = OnboardingQuiz.questions[stepIndex - 1]
                    QuizScreen(question: question) { answer in
                        record(answer, for: question.id)
                        advance()
                    }
                    .id(question.id)
                case quizCount + 1:
                    AnalyzingScreen { advance() }
                default:
                    PlanScreen(lines: OnboardingQuiz.profileLines(goal: goalAnswer, pain: painAnswer)) {
                        onComplete()
                    }
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .animation(.snappy, value: stepIndex)
    }

    private func advance() {
        stepIndex += 1
    }

    private func record(_ answer: String, for questionID: String) {
        switch questionID {
        case "load": loadAnswer = answer
        case "goal": goalAnswer = answer
        case "pain": painAnswer = answer
        default: break
        }
    }
}

private struct WelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            VStack(spacing: 12) {
                Text("Most lifters have a form fault\nthey can't see.")
                    .font(.title.weight(.black))
                    .multilineTextAlignment(.center)
                Text("Bad form caps your progress and wears down your joints. FormCheck watches every rep — you just lift.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button(action: onContinue) {
                Text("Check My Form")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(24)
    }
}

private struct QuizScreen: View {
    let question: QuizQuestion
    let onAnswer: (String) -> Void

    @State private var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(question.title)
                    .font(.title.weight(.black))
                Text(question.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            VStack(spacing: 12) {
                ForEach(question.options) { option in
                    Button {
                        guard selected == nil else { return }
                        selected = option.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onAnswer(option.label)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Text(option.emoji)
                                .font(.title2)
                            Text(option.label)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selected == option.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selected == option.id ? Color.green.opacity(0.18) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selected == option.id ? Color.green : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(24)
    }
}

private struct AnalyzingScreen: View {
    let onFinished: () -> Void

    private let items = [
        "Calibrating depth thresholds",
        "Setting lean & tempo alerts",
        "Preparing your coaching profile",
    ]
    @State private var visibleCount = 0

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(.green)
            Text("Building your coaching profile…")
                .font(.title3.weight(.bold))
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 10) {
                        Image(systemName: index < visibleCount ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(index < visibleCount ? .green : .secondary)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(index < visibleCount ? .primary : .secondary)
                    }
                }
            }
            Spacer()
            Spacer()
        }
        .padding(24)
        .task {
            for step in 1...items.count {
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.snappy) { visibleCount = step }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            onFinished()
        }
    }
}

private struct PlanScreen: View {
    let lines: [String]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Your coaching profile is ready")
                    .font(.title.weight(.black))
                    .multilineTextAlignment(.center)
                Text("Here's what FormCheck will watch for you:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(lines, id: \.self) { line in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text(line)
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

            Label("100% on-device. Your video never leaves your phone.", systemImage: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(24)
    }
}

#Preview {
    OnboardingView {}
        .preferredColorScheme(.dark)
}
