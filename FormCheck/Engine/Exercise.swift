/// Lifts the app can score. Each brings its own fault rules; the rep state
/// machine is shared — it tracks the exercise's primary joint (hips for squat
/// and deadlift, wrists for bench).
enum Exercise: String, CaseIterable, Identifiable {
    case squat = "Squat"
    case deadlift = "Deadlift"
    case bench = "Bench"

    var id: String { rawValue }

    /// Lifts offered in the UI. Bench is withheld from v1 — a lying body is
    /// where on-device pose estimation is least reliable (Vision is trained
    /// mostly on upright people), so setup and tracking aren't solid enough
    /// to ship. Re-add `.bench` here once it's tuned against real footage.
    static var available: [Exercise] { [.squat, .deadlift] }

    /// Only squat: deadlift hides valgus behind the bar, and bench is
    /// side-view by geometry (the rack blocks a front camera anyway).
    var supportsFrontView: Bool { self == .squat }

    /// Bench tracks the bar via the wrists; everything else tracks the hips.
    var tracksWrists: Bool { self == .bench }
}
