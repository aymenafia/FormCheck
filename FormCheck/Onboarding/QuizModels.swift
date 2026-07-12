import Foundation

struct QuizOption: Identifiable {
    let emoji: String
    let label: String
    var id: String { label }
}

struct QuizQuestion: Identifiable {
    let id: String // AppStorage key suffix
    let title: String
    let subtitle: String
    let options: [QuizOption]
}

enum OnboardingQuiz {
    static let questions: [QuizQuestion] = [
        QuizQuestion(
            id: "load",
            title: "What's your current squat?",
            subtitle: "So we calibrate feedback to your level.",
            options: [
                QuizOption(emoji: "🏃", label: "Just bodyweight"),
                QuizOption(emoji: "🏋️", label: "Under 60 kg / 135 lb"),
                QuizOption(emoji: "💪", label: "60–100 kg / 135–225 lb"),
                QuizOption(emoji: "🦍", label: "Over 100 kg / 225 lb"),
            ]
        ),
        QuizQuestion(
            id: "goal",
            title: "What's your #1 goal?",
            subtitle: "Your coaching profile adapts to it.",
            options: [
                QuizOption(emoji: "📈", label: "Get stronger"),
                QuizOption(emoji: "🍗", label: "Build muscle"),
                QuizOption(emoji: "🎯", label: "Fix my technique"),
                QuizOption(emoji: "🛡️", label: "Avoid injury"),
            ]
        ),
        QuizQuestion(
            id: "pain",
            title: "Any aches after leg day?",
            subtitle: "Pain is usually a form signal, not a strength one.",
            options: [
                QuizOption(emoji: "🦵", label: "Knees"),
                QuizOption(emoji: "🔻", label: "Lower back"),
                QuizOption(emoji: "😬", label: "Both, sometimes"),
                QuizOption(emoji: "✅", label: "No pain"),
            ]
        ),
    ]

    /// Coaching-profile lines shown on the plan screen, tailored to answers.
    static func profileLines(goal: String, pain: String) -> [String] {
        var lines = [
            "Depth check on every single rep",
            "Live rep counting with voice callouts",
            "Slow-mo replays of your best & worst reps",
        ]
        if pain.contains("back") || pain.contains("Both") {
            lines.insert("Forward-lean alerts to protect your lower back", at: 1)
        } else if pain.contains("Knees") {
            lines.insert("Descent-control alerts to reduce knee stress", at: 1)
        } else {
            lines.insert("Tempo tracking to keep your descent controlled", at: 1)
        }
        if goal.contains("stronger") || goal.contains("muscle") {
            lines.append("Honest scores so every set counts")
        } else {
            lines.append("A grade per set so you see progress")
        }
        return lines
    }
}
