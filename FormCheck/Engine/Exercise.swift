/// Lifts the app can score. Each brings its own fault rules; the rep state
/// machine is shared — it tracks the exercise's primary joint (hips for squat
/// and deadlift, wrists for bench).
enum Exercise: String, CaseIterable, Identifiable {
    case squat = "Squat"
    case deadlift = "Deadlift"
    case bench = "Bench"

    var id: String { rawValue }

    /// Only squat: deadlift hides valgus behind the bar, and bench is
    /// side-view by geometry (the rack blocks a front camera anyway).
    var supportsFrontView: Bool { self == .squat }

    /// Bench tracks the bar via the wrists; everything else tracks the hips.
    var tracksWrists: Bool { self == .bench }
}
