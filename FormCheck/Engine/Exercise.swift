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

    /// Modes offered in the UI. Bench is withheld from v1 — a lying body is
    /// where on-device pose estimation is least reliable (Vision is trained
    /// mostly on upright people). Re-add `.bench` once tuned against footage.
    static var available: [Exercise] { [.squat, .deadlift, .freestyle] }

    var isFreestyle: Bool { self == .freestyle }

    /// Only squat: deadlift hides valgus behind the bar, and bench is
    /// side-view by geometry (the rack blocks a front camera anyway).
    var supportsFrontView: Bool { self == .squat }

    /// Bench tracks the bar via the wrists; everything else tracks the hips.
    var tracksWrists: Bool { self == .bench }
}
