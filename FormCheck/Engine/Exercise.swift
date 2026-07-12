/// Lifts the app can score. Each brings its own fault rules; the rep state
/// machine is shared — it tracks the exercise's primary joint (hips for squat
/// and deadlift, wrists for bench).
enum Exercise: String, CaseIterable, Identifiable {
    case squat = "Squat"
    case deadlift = "Deadlift"
    case bench = "Bench"
    /// Not a scored lift: shows the live skeleton and records a shareable clip
    /// with the skeleton burned in. No form scoring — that would need a
    /// reference routine to compare against (a future feature).
    case freestyle = "Freestyle"

    var id: String { rawValue }

    /// Modes offered in the UI. v1 ships the two reliable lifts only.
    /// Bench is withheld (a lying body is where on-device pose estimation is
    /// least reliable). Freestyle is withheld too — kept focused for launch;
    /// both are one line away from returning once validated/tuned.
    static var available: [Exercise] { [.squat, .deadlift] }

    var isFreestyle: Bool { self == .freestyle }

    /// Only squat: deadlift hides valgus behind the bar, and bench is
    /// side-view by geometry (the rack blocks a front camera anyway).
    var supportsFrontView: Bool { self == .squat }

    /// Bench tracks the bar via the wrists; everything else tracks the hips.
    var tracksWrists: Bool { self == .bench }
}
