/// Lifts the app can score. Each brings its own fault rules; the rep state
/// machine is shared — it tracks the exercise's primary joint (hips for squat
/// and deadlift, wrists for bench).
enum Exercise: String, CaseIterable, Identifiable {
    case squat = "Squat"
    case deadlift = "Deadlift"
    case overheadPress = "Overhead Press"
    case lunge = "Lunge"
    case bench = "Bench"
    /// Not a scored lift: shows the live skeleton and records a shareable clip
    /// with the skeleton burned in. No form scoring — that would need a
    /// reference routine to compare against (a future feature).
    case freestyle = "Freestyle"

    var id: String { rawValue }

    /// Short label for the segmented picker (four segments get cramped).
    var pickerLabel: String { self == .overheadPress ? "Press" : rawValue }

    /// Modes offered in the UI. All four here are upright/standing movements
    /// where on-device pose estimation is reliable. Bench (lying body) and
    /// Freestyle are withheld — both one line from returning.
    static var available: [Exercise] { [.squat, .deadlift, .overheadPress, .lunge] }

    var isFreestyle: Bool { self == .freestyle }

    /// Front view adds value only for squat (knee valgus). The rest read best side-on.
    var supportsFrontView: Bool { self == .squat }

    /// Bench and overhead press track the bar via the wrists; the rest track the hips.
    var tracksWrists: Bool { self == .bench || self == .overheadPress }

    /// Which way the tracked joint moves first in a rep. Squat/deadlift/lunge
    /// drop then rise (down-first). Overhead press goes up then down (up-first).
    enum RepDirection { case down, up }
    var repDirection: RepDirection { self == .overheadPress ? .up : .down }
}
