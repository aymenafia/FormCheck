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
            id: "goal",
            title: "What's your #1 goal?",
            subtitle: "Your coaching plan adapts to it.",
            options: [
                QuizOption(emoji: "📈", label: "Get stronger"),
                QuizOption(emoji: "💪", label: "Build muscle"),
                QuizOption(emoji: "🎯", label: "Fix my technique"),
                QuizOption(emoji: "🛡️", label: "Avoid injury"),
            ]
        ),
        QuizQuestion(
            id: "load",
            title: "How experienced are you?",
            subtitle: "So feedback matches your level.",
            options: [
                QuizOption(emoji: "🌱", label: "Just starting out"),
                QuizOption(emoji: "🏋️", label: "Under 1 year"),
                QuizOption(emoji: "🔥", label: "1–3 years"),
                QuizOption(emoji: "🦍", label: "3+ years"),
            ]
        ),
        QuizQuestion(
            id: "pain",
            title: "Any aches after leg day?",
            subtitle: "Pain is often a form signal, not a strength one.",
            options: [
                QuizOption(emoji: "🦵", label: "Knees"),
                QuizOption(emoji: "🔻", label: "Lower back"),
                QuizOption(emoji: "😬", label: "Both, sometimes"),
                QuizOption(emoji: "✅", label: "No pain"),
            ]
        ),
        QuizQuestion(
            id: "place",
            title: "Where do you train?",
            subtitle: "FormCheck works anywhere your phone can stand.",
            options: [
                QuizOption(emoji: "🏢", label: "Commercial gym"),
                QuizOption(emoji: "🏠", label: "Home or garage gym"),
                QuizOption(emoji: "🤸", label: "Bodyweight, anywhere"),
                QuizOption(emoji: "🔀", label: "A mix"),
            ]
        ),
    ]

    /// Coaching-plan lines shown on the plan screen, tailored to answers.
    static func profileLines(goal: String, pain: String, place: String) -> [String] {
        var lines = [
            "Depth check on every single rep",
            "Live rep counting with voice callouts",
            "Slow-mo skeleton replays of your best & worst reps",
        ]
        if pain.contains("back") || pain.contains("Both") {
            lines.insert("Forward-lean alerts to protect your lower back", at: 1)
        } else if pain.contains("Knees") {
            lines.insert("Knee-tracking alerts (front view) to catch knee cave", at: 1)
        } else {
            lines.insert("Tempo tracking to keep your descent controlled", at: 1)
        }
        if place.contains("Bodyweight") {
            lines.append("Bodyweight squats & lunges count — no barbell needed")
        }
        if goal.contains("stronger") || goal.contains("muscle") {
            lines.append("An honest A–F grade so every set counts")
        } else {
            lines.append("A grade per set so you can see yourself improve")
        }
        return lines
    }
}
